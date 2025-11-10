import os
import torch
import coremltools as ct
from ultralytics import YOLO

# -----------------------------
# Configuration
# -----------------------------
# Set the minimum deployment target for better compatibility
MINIMUM_DEPLOYMENT_TARGET = ct.target.iOS15

# ImageNet preprocessing parameters for torchvision models
# These are standard values used by PyTorch pretrained models
IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]

# Calculate scale and bias for CoreML
# CoreML applies: output = input * scale + bias
# PyTorch applies: output = (input / 255 - mean) / std
# To convert: output = input / (std * 255) - mean / std
scale = 1.0 / (0.226 * 255.0)  # Using average std value
bias = [
    -IMAGENET_MEAN[0] / IMAGENET_STD[0],
    -IMAGENET_MEAN[1] / IMAGENET_STD[1],
    -IMAGENET_MEAN[2] / IMAGENET_STD[2]
]


# -----------------------------
# Helper: Export PyTorch Models → CoreML
# -----------------------------
def export_pytorch_model_to_coreml(model, name, input_size=(1, 3, 224, 224), use_image_input=True):
    """
    Export a PyTorch model to CoreML format with proper preprocessing.

    Args:
        model: PyTorch model to export
        name: Name for the output file
        input_size: Input tensor size (batch, channels, height, width)
        use_image_input: Whether to use ImageType (recommended) or TensorType
    """
    print(f"\n=== Exporting {name} ===")

    # CRITICAL: Set model to evaluation mode
    model.eval()

    # Create example input for tracing
    example_input = torch.randn(*input_size)

    # Trace the model with torch.jit
    print(f"Tracing model...")
    with torch.no_grad():
        traced_model = torch.jit.trace(model, example_input)
        traced_model.eval()

    # Define input type with preprocessing
    if use_image_input:
        # Using ImageType with proper preprocessing (RECOMMENDED)
        image_input = ct.ImageType(
            name="image",
            shape=input_size,
            scale=scale,
            bias=bias,
            color_layout=ct.colorlayout.RGB
        )
        inputs = [image_input]
    else:
        # Using TensorType (alternative, but requires manual preprocessing)
        inputs = [ct.TensorType(name="input", shape=input_size)]

    # Convert to CoreML with proper configuration
    print(f"Converting to CoreML...")
    try:
        mlmodel = ct.convert(
            traced_model,
            inputs=inputs,
            convert_to="mlprogram",  # Use ML Program format for iOS 15+
            minimum_deployment_target=MINIMUM_DEPLOYMENT_TARGET,
            compute_precision=ct.precision.FLOAT16  # Use FP16 for better performance
        )

        # Save the model
        output_path = f"{name}.mlpackage"
        mlmodel.save(output_path)
        print(f"✅ Successfully saved: {output_path}")

        return mlmodel

    except Exception as e:
        print(f"❌ Error converting {name}: {str(e)}")
        return None


# -----------------------------
# 1. YOLOv8x Classification (Ultralytics)
# -----------------------------
print("\n=== Exporting YOLOv8x-cls ===")
try:
    # Load the model
    yolo_cls = YOLO("yolov8x-cls.pt")

    # Export with FP16 (default)
    yolo_cls.export(format="coreml", half=True)
    print("✅ Saved: yolov8x-cls.mlpackage (FP16)")

    # Export with INT8 quantization
    yolo_cls.export(format="coreml", int8=True)
    # Rename the INT8 version
    if os.path.exists("yolov8x-cls.mlpackage"):
        if os.path.exists("yolov8x-cls-int8.mlpackage"):
            import shutil
            shutil.rmtree("yolov8x-cls-int8.mlpackage")
        os.rename("yolov8x-cls.mlpackage", "yolov8x-cls-int8.mlpackage")
    print("✅ Saved: yolov8x-cls-int8.mlpackage (INT8)")

except Exception as e:
    print(f"❌ Error with YOLOv8x-cls: {str(e)}")


# -----------------------------
# 2. FastViT (from timm)
# -----------------------------
try:
    import timm

    print("\n=== Exporting FastViT ===")
    # Create model and set to eval mode
    fastvit_model = timm.create_model("fastvit_t12", pretrained=True)

    # Export with proper preprocessing
    export_pytorch_model_to_coreml(
        model=fastvit_model,
        name="fastvit_t12",
        input_size=(1, 3, 224, 224),
        use_image_input=True
    )

except ImportError:
    print("❌ timm library not found. Install with: pip install timm")
except Exception as e:
    print(f"❌ Error with FastViT: {str(e)}")


# -----------------------------
# 3. MobileNetV2
# -----------------------------
try:
    from torchvision.models import mobilenet_v2, MobileNet_V2_Weights

    print("\n=== Exporting MobileNetV2 ===")
    # Load pretrained model with new weights API
    mobilenet = mobilenet_v2(weights=MobileNet_V2_Weights.IMAGENET1K_V1)

    # Export with proper preprocessing
    export_pytorch_model_to_coreml(
        model=mobilenet,
        name="mobilenetv2",
        input_size=(1, 3, 224, 224),
        use_image_input=True
    )

except Exception as e:
    print(f"❌ Error with MobileNetV2: {str(e)}")


# -----------------------------
# 4. ResNet50
# -----------------------------
try:
    from torchvision.models import resnet50, ResNet50_Weights

    print("\n=== Exporting ResNet50 ===")
    # Load pretrained model with new weights API
    resnet = resnet50(weights=ResNet50_Weights.IMAGENET1K_V1)

    # Export with proper preprocessing
    export_pytorch_model_to_coreml(
        model=resnet,
        name="resnet50",
        input_size=(1, 3, 224, 224),
        use_image_input=True
    )

except Exception as e:
    print(f"❌ Error with ResNet50: {str(e)}")


print("\n" + "="*50)
print("Conversion Complete!")
print("="*50)
print("\nIMPORTANT NOTES:")
print("All models use ImageType with proper ImageNet preprocessing")
