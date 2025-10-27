/// Copyright (c) 2025 Kodeco Inc.
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import SwiftUI
import FoundationModels

struct FoodMenuView: View {
    // Store generated menus and specials per meal type
    @State var menus: [String: RestaurantMenu.PartiallyGenerated] = [:]
    @State var specials: [String: MenuItem] = [:]
    // Persistent display versions for saved data (survive view reopen)
    @State private var savedDisplayMenus: [String: [SavedMenuItem]] = [:]
    @State private var savedDisplaySpecials: [String: SavedMenuItem] = [:]
    // Loading state per meal for showing a small progress bar
    @State private var loadingMeals: Set<String> = []
    // Track completion per meal to show a checkmark when generation finishes
    @State private var completedMeals: Set<String> = []
    @State var ingredients: String = "lamb, salmon, duck"
    
    // New state: options and selections for meal and restaurant types
    let mealOptions = ["Breakfast", "Brunch", "Lunch", "Dinner"]
    // Allow multiple meal selections
    @State private var selectedMeals: Set<String> = []
    // Track fresh selections (user just switched on) so we can show a 'fresh' icon
    @State private var freshMeals: Set<String> = []
    // Track expanded/collapsed state per meal
    @State private var expandedMeals: Set<String> = []
    
    let restaurantOptions = ["Fine Dining", "Diner", "Casual Dining", "Fast Food", "Pub"]
    @State private var selectedRestaurant: String? = nil
    
    // Persistence key
    private let savedMenusKey = "SavedRestaurantMenus_v1"
    
    var ingredientArray: [String] {
        let array = ingredients.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if array.isEmpty {
            return ["lamb", "salmon", "duck"]
        } else {
            return array
        }
    }
    
    // Computed button label moved out of the ViewBuilder to avoid placing statements directly in the body
    var buttonLabel: String {
        guard let rest = selectedRestaurant, !selectedMeals.isEmpty else { return "Generate Menu" }
        let meals = Array(selectedMeals)
        if meals.count == 1, let meal = meals.first {
            return "Generate \(meal) Menu — \(rest)"
        } else {
            // For multiple meals, show count
            return "Generate \(meals.count) Menus — \(rest)"
        }
    }
    
    // MARK: - Saved display models for persistence
    struct SavedMenuItem: Codable, Identifiable {
        var id: String { name + String(cost) }
        let name: String
        let description: String
        let ingredients: [String]
        let cost: Double
    }
    
    struct SavedMenusContainer: Codable {
        var menus: [String: [SavedMenuItem]]
        var specials: [String: SavedMenuItem]
    }
    
    // Small view for SavedMenuItem display (used when showing persisted content)
    struct SavedMenuItemView: View {
        let item: SavedMenuItem
        var body: some View {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.name)
                            .font(.headline)
                        Spacer()
                        Text(item.cost, format: .currency(code: "USD"))
                    }
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    if !item.ingredients.isEmpty {
                        Text(item.ingredients.joined(separator: " • "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // Updated to use selectedMeal and selectedRestaurant. Streaming behavior preserved.
    func generateMenu() async {
        guard let restaurant = selectedRestaurant, !selectedMeals.isEmpty else { return }
        
        // Mark all selected meals as loading so their headers show the loader immediately
        DispatchQueue.main.async {
            loadingMeals.formUnion(selectedMeals)
        }
        
        // For each selected meal, stream a separate menu generation and store the partial result keyed by meal
        for meal in selectedMeals.sorted() {
            let session = LanguageModelSession(instructions: "You are a helpful model assisting with generating realistic restaurant menus.")
            let prompt = "Create a menu for \(meal.lowercased()) at a \(restaurant.lowercased()) restaurant. Include appropriate sections (appetizers, mains, desserts, beverages where applicable) and realistic dish names, short descriptions, and prices in USD. Keep the tone and portioning appropriate for a \(restaurant.lowercased()). Respond with a structured RestaurantMenu object."
            let streamedResponse = session.streamResponse(to: prompt, generating: RestaurantMenu.self)
            do {
                // Stream partial responses into the UI as they arrive. Persist to savedDisplayMenus only after completion.
                for try await partialResponse in streamedResponse {
                    // Update the transient menu so the View shows partial/streamed content immediately
                    DispatchQueue.main.async {
                        menus[meal] = partialResponse.content
                    }
                }
                
                // After streaming completes, persist final content (if any) into savedDisplayMenus
                if let finalContent = menus[meal], let finalMenuItems = finalContent.menu {
                    let savedItems = finalMenuItems.map { part -> SavedMenuItem in
                        let name = part.name ?? ""
                        let desc = part.description ?? ""
                        let ingredients = part.ingredients ?? []
                        let cost: Double
                        if let c = part.cost as Decimal? {
                            cost = NSDecimalNumber(decimal: c).doubleValue
                        } else {
                            cost = 0.0
                        }
                        return SavedMenuItem(name: name, description: desc, ingredients: ingredients, cost: cost)
                    }
                    DispatchQueue.main.async {
                        savedDisplayMenus[meal] = savedItems
                        saveAllSavedMenus()
                    }
                }
                
                // stream completed successfully for this meal: update loader/completion state
                DispatchQueue.main.async {
                    loadingMeals.remove(meal)
                    completedMeals.insert(meal)
                }
             } catch {
                 print("Error generating menu for \(meal): \(error.localizedDescription)")
                 DispatchQueue.main.async { loadingMeals.remove(meal) }
             }
         }
     }

    func generateMenuSpecial() async {
        guard let restaurant = selectedRestaurant, !selectedMeals.isEmpty else { return }
        
        // 1
        let specialMealSchema = DynamicGenerationSchema(
            name: "specialmenuitem",
            // 2
            properties: [
                // 3
                DynamicGenerationSchema.Property(
                    name: "ingredients",
                    // 4
                    schema: DynamicGenerationSchema(
                        name: "ingredients",
                        anyOf: ingredientArray
                    )
                ),
                // 5
                DynamicGenerationSchema.Property(
                    name: "name",
                    schema: DynamicGenerationSchema(type: String.self)
                ),
                DynamicGenerationSchema.Property(
                    name: "description",
                    schema: DynamicGenerationSchema(type: String.self)
                ),
                DynamicGenerationSchema.Property(
                    name: "price",
                    schema: DynamicGenerationSchema(type: Decimal.self)
                )
            ]
        )
        
        // 1
        let schema = try? GenerationSchema(root: specialMealSchema, dependencies: [])
        // 2
        guard let schema = schema else { return }
        // 3
        let session = LanguageModelSession(instructions: "You are a helpful model assisting with generating realistic restaurant menus.")
        // Generate a special per selected meal
        for meal in selectedMeals.sorted() {
            let specialPrompt = "Produce a \(meal.lowercased()) special menu item for a \(restaurant.lowercased()) restaurant that highlights the specified ingredient. Keep the description concise and include a reasonable price."
            // Await the generation response; do not persist special until after generation completes for the meal
            if let response = try? await session.respond(to: specialPrompt, schema: schema) {
                let name = (try? response.content.value(String.self, forProperty: "name")) ?? ""
                let ingredientsValue = (try? response.content.value(String.self, forProperty: "ingredients"))
                let description = (try? response.content.value(String.self, forProperty: "description")) ?? ""
                let price = (try? response.content.value(Decimal.self, forProperty: "price")) ?? 0.0
                let specialItem = MenuItem(
                    name: name,
                    description: description,
                    ingredients: ingredientsValue == nil ? [] : [ingredientsValue!],
                    cost: price
                )

                // Update UI model after generation finishes for this meal
                DispatchQueue.main.async {
                    specials[meal] = specialItem
                    // Persist special into savedDisplaySpecials after generation complete
                    let savedSpecial = SavedMenuItem(name: specialItem.name, description: specialItem.description, ingredients: specialItem.ingredients, cost: NSDecimalNumber(decimal: specialItem.cost).doubleValue)
                    savedDisplaySpecials[meal] = savedSpecial
                    saveAllSavedMenus()
                }
            }
         }
     }
    
    // MARK: - Persistence helpers
    private func saveAllSavedMenus() {
        let container = SavedMenusContainer(menus: savedDisplayMenus, specials: savedDisplaySpecials)
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(container)
            UserDefaults.standard.set(data, forKey: savedMenusKey)
        } catch {
            print("Failed to save menus: \(error)")
        }
    }
    
    private func loadSavedMenus() {
        guard let data = UserDefaults.standard.data(forKey: savedMenusKey) else {
            // nothing saved yet — update saved containers only; preserve user's expanded/selected/loading UI state
            DispatchQueue.main.async {
                savedDisplayMenus = [:]
                savedDisplaySpecials = [:]
            }
            return
        }
        let decoder = JSONDecoder()
        do {
            let container = try decoder.decode(SavedMenusContainer.self, from: data)
            DispatchQueue.main.async {
                // Update persisted saved menus/specials only; do not modify expandedMeals/selectedMeals/loadingMeals
                savedDisplayMenus = container.menus
                savedDisplaySpecials = container.specials
            }
        } catch {
            print("Failed to load saved menus: \(error)")
            DispatchQueue.main.async {
                savedDisplayMenus = [:]
                savedDisplaySpecials = [:]
            }
        }
    }
    
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                // Meal type multi-selection (toggles)
                VStack(alignment: .leading) {
                    Text("Meal:")
                        .bold()
                    // Use a two-column grid
                    let columns = [GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(mealOptions, id: \.self) { meal in
                            Toggle(isOn: Binding(get: {
                                selectedMeals.contains(meal)
                            }, set: { isOn in
                                if isOn {
                                    // User turned on this meal: mark as selected and fresh, clear previous in-memory streaming results
                                    selectedMeals.insert(meal)
                                    freshMeals.insert(meal)
                                    menus[meal] = nil
                                    specials[meal] = nil
                                } else {
                                    selectedMeals.remove(meal)
                                    // If the meal is deselected collapse its expanded state
                                    expandedMeals.remove(meal)
                                    // clear fresh flag
                                    freshMeals.remove(meal)
                                }
                            })) {
                                Text(meal)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .toggleStyle(.automatic)
                        }
                    }
                }
                
                // Restaurant picker 
                VStack(alignment: .leading, spacing: 8) {
                    // Row 1: Restaurant label + picker
                    HStack(alignment: .center, spacing: 8) {
                        Text("Restaurant:")
                            .bold()
                            // keep label compact so the picker can expand
                            .fixedSize()

                        Picker(selection: $selectedRestaurant) {
                            Text("Select a restaurant").tag(String?.none)
                            ForEach(restaurantOptions, id: \.self) { rest in
                                Text(rest).tag(Optional(rest))
                            }
                        } label: {
                            // explicit label shows the current selection (or placeholder) and is constrained to a single line
                            Text(selectedRestaurant ?? "Select a restaurant")
                              .lineLimit(1)
                              .truncationMode(.tail)
                              .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .pickerStyle(MenuPickerStyle())
                        .layoutPriority(1)
                    }
                    
                    // Row 2: Ingredients label + current ingredients value
                    HStack(alignment: .center) {
                        Text("Ingredients:")
                            .bold()
                        Spacer()
                        Text(ingredients)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                    }
                    
                    // Row 3: Editable text field for ingredients (full-width constrained)
                    HStack {
                        TextField("Edit ingredients", text: $ingredients)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 560)
                        Spacer()
                    }
                }
                
                // Button text reflects user's choices; disable until both selections are made
                Button(buttonLabel) {
                  Task {
                    // --- UI refresh immediately (global clear first) ---
                    // 1) Clear ALL persisted saved menus/specials so history is wiped completely
                    savedDisplayMenus = [:]
                    savedDisplaySpecials = [:]
                    // 2) Persist the clearing immediately
                    saveAllSavedMenus()
                    
                    // 3) Clear ephemeral in-memory menu/special content and completion state
                    menus = [:]
                    specials = [:]
                    completedMeals = []
                    
                    // 4) Expand selected meals and set loader state so UI shows selection + loader right away
                    expandedMeals = Set(selectedMeals)
                    loadingMeals = Set(selectedMeals)
                    
                    // Start generation (which will repopulate savedDisplayMenus/specials as streaming completes)
                    await generateMenu()
                    await generateMenuSpecial()
                  }
                }
                .disabled(selectedMeals.isEmpty || selectedRestaurant == nil || !loadingMeals.isEmpty)
            }
            .padding(.bottom, 8)
            
            Divider()
            
            // Content area: make this the only scrollable region so top controls remain fixed
            ScrollView {
                VStack(spacing: 0) {
                    // Available saved menus: show saved content regardless of toggle selection,
                    // but do not duplicate saved menus for meals that are currently selected.
                    if !savedDisplayMenus.isEmpty || !savedDisplaySpecials.isEmpty {
                        Text("Available Saved Menus")
                            .font(.title3)
                            .bold()
                            .padding(.top, 8)
                        // Build the union of meals that have saved menu or special
                        let savedMealsRaw = Array(Set(savedDisplayMenus.keys).union(Set(savedDisplaySpecials.keys))).sorted()
                        let savedMeals = savedMealsRaw.filter { !selectedMeals.contains($0) }
                        if !savedMeals.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(savedMeals, id: \.self) { meal in
                                    VStack(alignment: .leading) {
                                        HStack {
                                            Text(meal)
                                                .font(.headline)
                                            Spacer()
                                            Button(action: {
                                                if expandedMeals.contains(meal) {
                                                    expandedMeals.remove(meal)
                                                } else {
                                                    expandedMeals.insert(meal)
                                                }
                                            }) {
                                                Image(systemName: expandedMeals.contains(meal) ? "chevron.down" : "chevron.right")
                                                    .foregroundColor(.blue)
                                                    .imageScale(.small)
                                            }
                                            .buttonStyle(.plain)
                                            // Show checkmark for saved content
                                            if savedDisplayMenus[meal] != nil || savedDisplaySpecials[meal] != nil {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                                    .imageScale(.small)
                                                    .frame(width: 20, height: 20)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            if expandedMeals.contains(meal) {
                                                expandedMeals.remove(meal)
                                            } else {
                                                expandedMeals.insert(meal)
                                            }
                                        }
                                        
                                        if expandedMeals.contains(meal) {
                                            // Show saved special then saved menu items inside a scrollable area
                                            ScrollView(.vertical) {
                                                VStack(alignment: .leading, spacing: 8) {
                                                    if let savedSpecial = savedDisplaySpecials[meal] {
                                                        Text("Today's Special")
                                                            .font(.subheadline)
                                                            .foregroundColor(.primary)
                                                        SavedMenuItemView(item: savedSpecial)
                                                        Divider()
                                                    }
                                                    if let savedItems = savedDisplayMenus[meal] {
                                                        Text("\(meal) Menu")
                                                            .font(.subheadline)
                                                            .foregroundColor(.primary)
                                                        ForEach(savedItems) { item in
                                                            SavedMenuItemView(item: item)
                                                            Divider()
                                                        }
                                                    } else {
                                                        Text("No saved menu for this meal.")
                                                            .font(.footnote)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                .padding(.horizontal, 4)
                                            }
                                            .frame(maxHeight: 300)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                    .animation(.default, value: expandedMeals)
                                    Divider()
                                }
                            }
                        }
                    }
                    
                    // Collapsible sections per selected meal
                    ForEach(selectedMeals.sorted(), id: \.self) { meal in
                        VStack(alignment: .leading) {
                            // Header with toggle
                            HStack {
                                Text(meal)
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    // toggle expanded state
                                    if expandedMeals.contains(meal) {
                                        expandedMeals.remove(meal)
                                    } else {
                                        expandedMeals.insert(meal)
                                    }
                                }) {
                                    Image(systemName: expandedMeals.contains(meal) ? "chevron.down" : "chevron.right")
                                        .foregroundColor(.blue)
                                        .imageScale(.small)
                                }
                                .buttonStyle(.plain)
                                if loadingMeals.contains(meal) {
                                    // loader
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .frame(width: 20, height: 20)
                                } else if completedMeals.contains(meal) || savedDisplayMenus[meal] != nil || menus[meal] != nil {
                                    // Show only the checkmark once completed or if saved/present
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .imageScale(.small)
                                        .frame(width: 20, height: 20)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if expandedMeals.contains(meal) {
                                    expandedMeals.remove(meal)
                                } else {
                                    expandedMeals.insert(meal)
                                }
                            }
                            
                            if expandedMeals.contains(meal) {
                                // Scrollable container so long menus and descriptions are fully visible
                                ScrollView(.vertical) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Special
                                        if let savedSpecial = savedDisplaySpecials[meal] {
                                            Text("Today's Special")
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            SavedMenuItemView(item: savedSpecial)
                                            Divider()
                                        } else if let special = specials[meal] {
                                            Text("Today's Special")
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            MenuItemView(menuItem: special.asPartiallyGenerated())
                                                .fixedSize(horizontal: false, vertical: true)
                                            Divider()
                                        }
                                        
                                        // Menu items (if available)
                                        if let savedItems = savedDisplayMenus[meal] {
                                            Text("\(meal) Menu")
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            ForEach(savedItems) { item in
                                                SavedMenuItemView(item: item)
                                                Divider()
                                            }
                                        } else if let menu = menus[meal], let menuItems = menu.menu {
                                            Text("\(meal) Menu")
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            VStack(spacing: 8) {
                                                ForEach(menuItems, id: \.name) { item in
                                                    MenuItemView(menuItem: item)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                    Divider()
                                                }
                                            }
                                        } else {
                                            Text("No menu yet. Tap Generate to create one.")
                                                .font(.footnote)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 4)
                                }
                                .frame(maxHeight: 300)
                            }
                        }
                        .padding(.vertical, 6)
                        .animation(.default, value: expandedMeals)
                        Divider()
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 16)
            }
        }
        .padding()
        .onAppear {
            loadSavedMenus()
        }
        // Observe changes to UserDefaults so if the user clears history elsewhere we reload/clear
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            loadSavedMenus()
        }
    }
    
}
