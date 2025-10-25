# Funny Faces (03_Funny-Faces)

This SwiftUI app detects faces in an imported photo and draws "googly eyes" over each detected eye using Apple's Vision framework.

What it does:
- Import photos using the PhotosPicker.
- Detect face landmarks using VNDetectFaceLandmarksRequest.
- Draw white circles and black pupils over each detected eye.
- Share the processed image using ShareLink.

Notes:
- This project runs on the physical device for image import via the PhotosPicker. In simulator detection and drawing is not accurate so please try to use physical device for more accurate results.

How to run:
1. Open the Xcode project `03_Funny-Faces.xcodeproj`.
2. Build & run on a device (iOS 16+ recommended).
3. Import an image from the Photos picker, apply filters.
