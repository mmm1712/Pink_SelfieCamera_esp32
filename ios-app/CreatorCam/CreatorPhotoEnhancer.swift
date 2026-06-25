import UIKit
import CoreImage
import CoreML
import Vision
import ImageIO

enum CreatorOnDeviceAIEnhancerError: LocalizedError {
    case modelMissing
    case inputDecodeFailed
    case outputMissing
    case outputUnsupported
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            return "Add the RealESRGAN model to the Xcode project first."
        case .inputDecodeFailed:
            return "Could not read the selected photo."
        case .outputMissing:
            return "The enhancer did not return an image."
        case .outputUnsupported:
            return "The enhancer output format is not supported yet."
        case .renderFailed:
            return "Could not render the enhanced image."
        }
    }
}

struct CreatorPhotoAdjustments: Equatable, Sendable {
    var exposure: Double = 0.0
    var brightness: Double = 0.0
    var contrast: Double = 1.0
    var saturation: Double = 1.0
    var warmth: Double = 0.0
    var highlights: Double = 0.0
    var shadows: Double = 0.0
    var sharpen: Double = 0.0
    var grain: Double = 0.0
    var vignette: Double = 0.0

    nonisolated static let neutral = CreatorPhotoAdjustments()

    nonisolated var isNeutral: Bool {
        exposure == 0.0 &&
        brightness == 0.0 &&
        contrast == 1.0 &&
        saturation == 1.0 &&
        warmth == 0.0 &&
        highlights == 0.0 &&
        shadows == 0.0 &&
        sharpen == 0.0 &&
        grain == 0.0 &&
        vignette == 0.0
    }

    nonisolated static func == (lhs: CreatorPhotoAdjustments, rhs: CreatorPhotoAdjustments) -> Bool {
        lhs.exposure == rhs.exposure &&
        lhs.brightness == rhs.brightness &&
        lhs.contrast == rhs.contrast &&
        lhs.saturation == rhs.saturation &&
        lhs.warmth == rhs.warmth &&
        lhs.highlights == rhs.highlights &&
        lhs.shadows == rhs.shadows &&
        lhs.sharpen == rhs.sharpen &&
        lhs.grain == rhs.grain &&
        lhs.vignette == rhs.vignette
    }
}

enum CreatorPhotoLook: String, CaseIterable, Identifiable, Sendable {
    case enhance
    case dreamy
    case softGlow
    case retro
    case warmFilm
    case coolFilm
    case disposable
    case flashPop
    case toy
    case vivid
    case chrome
    case faded
    case pastel
    case latte
    case mint
    case blueHour
    case noir
    case monoSoft
    case holo
    case riso
    case glitch
    case cyber
    case vhs
    case zine
    case comic
    case aura

    var id: String { rawValue }

    static var filterCases: [CreatorPhotoLook] {
        allCases.filter { $0 != .enhance }
    }

    var title: String {
        switch self {
        case .enhance:
            return "Enhance"
        case .dreamy:
            return "Dreamy"
        case .softGlow:
            return "Soft Glow"
        case .retro:
            return "Retro"
        case .warmFilm:
            return "Warm Film"
        case .coolFilm:
            return "Cool Film"
        case .disposable:
            return "Disposable"
        case .flashPop:
            return "Flash"
        case .toy:
            return "Toy Cam"
        case .vivid:
            return "Vivid"
        case .chrome:
            return "Chrome"
        case .faded:
            return "Fade"
        case .pastel:
            return "Pastel"
        case .latte:
            return "Latte"
        case .mint:
            return "Mint"
        case .blueHour:
            return "Blue Hour"
        case .noir:
            return "Noir"
        case .monoSoft:
            return "Mono Soft"
        case .holo:
            return "Holo"
        case .riso:
            return "Riso"
        case .glitch:
            return "Glitch"
        case .cyber:
            return "Cyber"
        case .vhs:
            return "VHS"
        case .zine:
            return "Zine"
        case .comic:
            return "Comic"
        case .aura:
            return "Aura"
        }
    }

    var systemImage: String {
        switch self {
        case .enhance:
            return "sparkles"
        case .dreamy:
            return "cloud.sun.fill"
        case .softGlow:
            return "sun.max.fill"
        case .retro:
            return "camera.filters"
        case .warmFilm:
            return "sunset.fill"
        case .coolFilm:
            return "snowflake"
        case .disposable:
            return "camera.fill"
        case .flashPop:
            return "bolt.circle.fill"
        case .toy:
            return "circle.dashed"
        case .vivid:
            return "paintpalette.fill"
        case .chrome:
            return "circle.lefthalf.filled"
        case .faded:
            return "circle.righthalf.filled"
        case .pastel:
            return "paintbrush.pointed.fill"
        case .latte:
            return "cup.and.saucer.fill"
        case .mint:
            return "leaf.fill"
        case .blueHour:
            return "moon.stars.fill"
        case .noir:
            return "moon.fill"
        case .monoSoft:
            return "circle.fill"
        case .holo:
            return "sparkles"
        case .riso:
            return "circle.grid.2x2.fill"
        case .glitch:
            return "bolt.fill"
        case .cyber:
            return "laser.burst"
        case .vhs:
            return "videotape.fill"
        case .zine:
            return "newspaper.fill"
        case .comic:
            return "bubble.left.and.bubble.right.fill"
        case .aura:
            return "camera.macro"
        }
    }

    var requiresModel: Bool {
        self == .enhance
    }

    var fileSuffix: String {
        fileSuffix(enhanceFirst: false)
    }

    func requiresModel(enhanceFirst: Bool) -> Bool {
        self == .enhance || enhanceFirst
    }

    func fileSuffix(enhanceFirst: Bool) -> String {
        switch self {
        case .enhance:
            return "enhance_v5"
        default:
            return enhanceFirst ? "ai_look_\(rawValue)_v1" : "look_\(rawValue)_v1"
        }
    }
}

enum CreatorOnDeviceAIEnhancer {
    private nonisolated static let context = CIContext(options: [
        .useSoftwareRenderer: false
    ])

    private nonisolated static let modelResourceNames = [
        "RealESRGAN",
        "RealESRGAN_x4plus",
        "RealESRGAN_x2plus",
        "realesr-general-x4v3",
        "CreatorCamRealESRGAN"
    ]

    nonisolated static func isModelAvailable() -> Bool {
        modelURL() != nil
    }

    nonisolated static func enhanceJPEGData(_ data: Data) throws -> Data {
        try processJPEGData(data, look: .enhance)
    }

    nonisolated static func adjustJPEGData(
        _ data: Data,
        adjustments: CreatorPhotoAdjustments
    ) throws -> Data {
        guard let sourceImage = UIImage(data: data) else {
            throw CreatorOnDeviceAIEnhancerError.inputDecodeFailed
        }

        guard let adjustedImage = applyManualAdjustments(adjustments, to: sourceImage),
              let outputData = adjustedImage.jpegData(compressionQuality: 0.99) else {
            throw CreatorOnDeviceAIEnhancerError.renderFailed
        }

        return outputData
    }

    nonisolated static func previewImage(
        _ image: UIImage,
        adjustments: CreatorPhotoAdjustments
    ) -> UIImage? {
        guard !adjustments.isNeutral else {
            return image
        }

        return applyManualAdjustments(adjustments, to: image)
    }

    nonisolated static func processJPEGData(_ data: Data, look: CreatorPhotoLook) throws -> Data {
        try processJPEGData(data, look: look, enhanceFirst: false)
    }

    nonisolated static func processJPEGData(
        _ data: Data,
        look: CreatorPhotoLook,
        enhanceFirst: Bool
    ) throws -> Data {
        guard let sourceImage = UIImage(data: data) else {
            throw CreatorOnDeviceAIEnhancerError.inputDecodeFailed
        }

        let filteredImage = look == .enhance
            ? sourceImage
            : (applyCreativeLook(look, to: sourceImage) ?? sourceImage)

        if look == .enhance || enhanceFirst {
            let outputImage = try enhanceImage(filteredImage)
            guard let outputData = outputImage.jpegData(compressionQuality: 0.99) else {
                throw CreatorOnDeviceAIEnhancerError.renderFailed
            }

            return outputData
        }

        guard let outputData = filteredImage.jpegData(compressionQuality: 0.99) else {
            throw CreatorOnDeviceAIEnhancerError.renderFailed
        }

        return outputData
    }

    private nonisolated static func enhanceImage(_ inputImage: UIImage) throws -> UIImage {
        guard let cgImage = inputImage.cgImage else {
            throw CreatorOnDeviceAIEnhancerError.inputDecodeFailed
        }

        let model = try MLModel(contentsOf: try requireModelURL(), configuration: modelConfiguration())
        let visionModel = try VNCoreMLModel(for: model)
        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = .scaleFit

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: CGImagePropertyOrientation(inputImage.imageOrientation),
            options: [:]
        )

        try handler.perform([request])

        guard let aiImage = image(fromObservation: request.results?.first) else {
            throw CreatorOnDeviceAIEnhancerError.outputMissing
        }

        return finishEnhancedImage(aiImage, originalImage: inputImage) ?? aiImage
    }

    private nonisolated static func modelConfiguration() -> MLModelConfiguration {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        return configuration
    }

    private nonisolated static func requireModelURL() throws -> URL {
        guard let url = modelURL() else {
            throw CreatorOnDeviceAIEnhancerError.modelMissing
        }

        return url
    }

    private nonisolated static func modelURL() -> URL? {
        for name in modelResourceNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
                return url
            }
        }

        return nil
    }

    private nonisolated static func image(fromObservation observation: VNObservation?) -> UIImage? {
        if let pixelObservation = observation as? VNPixelBufferObservation {
            return image(from: pixelObservation.pixelBuffer)
        }

        if let featureObservation = observation as? VNCoreMLFeatureValueObservation {
            let featureValue = featureObservation.featureValue

            if let pixelBuffer = featureValue.imageBufferValue {
                return image(from: pixelBuffer)
            }

            if let array = featureValue.multiArrayValue {
                return image(from: array)
            }
        }

        return nil
    }

    private nonisolated static func image(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private nonisolated static func finishEnhancedImage(_ enhancedImage: UIImage, originalImage: UIImage) -> UIImage? {
        guard let enhancedCGImage = enhancedImage.cgImage else {
            return enhancedImage
        }

        let enhancedCIImage = CIImage(cgImage: enhancedCGImage)
        var workingImage = enhancedCIImage

        workingImage = applyFilter(
            "CINoiseReduction",
            to: workingImage,
            parameters: [
                "inputNoiseLevel": 0.028,
                "inputSharpness": 0.22
            ]
        )

        workingImage = applyFilter(
            "CIColorControls",
            to: workingImage,
            parameters: [
                kCIInputSaturationKey: 1.015,
                kCIInputContrastKey: 0.985,
                kCIInputBrightnessKey: 0.004
            ]
        )

        workingImage = applyFilter(
            "CIHighlightShadowAdjust",
            to: workingImage,
            parameters: [
                "inputHighlightAmount": 0.86,
                "inputShadowAmount": 0.18
            ]
        )

        workingImage = applyFilter(
            "CIGloom",
            to: workingImage,
            parameters: [
                kCIInputRadiusKey: 4.0,
                kCIInputIntensityKey: 0.12
            ]
        )

        workingImage = applyFilter(
            "CIUnsharpMask",
            to: workingImage,
            parameters: [
                kCIInputRadiusKey: 0.42,
                kCIInputIntensityKey: 0.18
            ]
        )

        guard let cgImage = context.createCGImage(workingImage, from: workingImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: originalImage.scale, orientation: .up)
    }

    private nonisolated static func applyCreativeLook(_ look: CreatorPhotoLook, to image: UIImage) -> UIImage? {
        guard let baseImage = orientedCIImage(from: image) else {
            return nil
        }

        var workingImage = baseImage

        switch look {
        case .enhance:
            return image
        case .dreamy:
            workingImage = applyFilter("CIPhotoEffectInstant", to: workingImage)
            workingImage = applyFilter(
                "CIGloom",
                to: workingImage,
                parameters: [
                    kCIInputRadiusKey: 9.0,
                    kCIInputIntensityKey: 0.32
                ]
            )
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 1.06,
                    kCIInputContrastKey: 0.91,
                    kCIInputBrightnessKey: 0.012
                ]
            )
            workingImage = applyVignette(to: workingImage, intensity: 0.22, radius: 1.6)
        case .softGlow:
            workingImage = applyFilter(
                "CIGloom",
                to: workingImage,
                parameters: [
                    kCIInputRadiusKey: 14.0,
                    kCIInputIntensityKey: 0.22
                ]
            )
            workingImage = applyFilter(
                "CIHighlightShadowAdjust",
                to: workingImage,
                parameters: [
                    "inputHighlightAmount": 0.82,
                    "inputShadowAmount": 0.34
                ]
            )
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 0.98,
                    kCIInputContrastKey: 0.88,
                    kCIInputBrightnessKey: 0.018
                ]
            )
            workingImage = overlayColor(
                CIColor(red: 1.0, green: 0.78, blue: 0.88, alpha: 0.14),
                over: workingImage,
                mode: "CISoftLightBlendMode"
            )
            workingImage = applyVignette(to: workingImage, intensity: 0.14, radius: 1.8)
        case .retro:
            workingImage = applyFilter("CIPhotoEffectTransfer", to: workingImage)
            workingImage = applyFilter(
                "CISepiaTone",
                to: workingImage,
                parameters: [
                    kCIInputIntensityKey: 0.16
                ]
            )
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 1.03,
                    kCIInputContrastKey: 1.04,
                    kCIInputBrightnessKey: 0.006
                ]
            )
            workingImage = applyVignette(to: workingImage, intensity: 0.58, radius: 1.25)
            workingImage = addGrain(to: workingImage, opacity: 0.045)
        case .warmFilm:
            workingImage = applyFilter("CIPhotoEffectProcess", to: workingImage)
            workingImage = applyFilter(
                "CITemperatureAndTint",
                to: workingImage,
                parameters: [
                    "inputNeutral": CIVector(x: 6500, y: 0),
                    "inputTargetNeutral": CIVector(x: 7600, y: 24)
                ]
            )
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 1.06,
                    kCIInputContrastKey: 0.98,
                    kCIInputBrightnessKey: 0.012
                ]
            )
            workingImage = applyVignette(to: workingImage, intensity: 0.34, radius: 1.45)
            workingImage = addGrain(to: workingImage, opacity: 0.035)
        case .coolFilm:
            workingImage = applyFilter("CIPhotoEffectFade", to: workingImage)
            workingImage = applyFilter(
                "CITemperatureAndTint",
                to: workingImage,
                parameters: [
                    "inputNeutral": CIVector(x: 6500, y: 0),
                    "inputTargetNeutral": CIVector(x: 5200, y: -12)
                ]
            )
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 0.96,
                    kCIInputContrastKey: 0.98,
                    kCIInputBrightnessKey: 0.006
                ]
            )
            workingImage = overlayColor(
                CIColor(red: 0.62, green: 0.86, blue: 1.0, alpha: 0.12),
                over: workingImage,
                mode: "CIScreenBlendMode"
            )
            workingImage = addGrain(to: workingImage, opacity: 0.024)
        case .disposable:
            workingImage = applyFilter("CIPhotoEffectTransfer", to: workingImage)
            workingImage = applyFilter(
                "CIExposureAdjust",
                to: workingImage,
                parameters: [
                    kCIInputEVKey: 0.14
                ]
            )
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 1.22,
                    kCIInputContrastKey: 1.18,
                    kCIInputBrightnessKey: 0.008
                ]
            )
            workingImage = applyVignette(to: workingImage, intensity: 0.84, radius: 0.92)
            workingImage = addGrain(to: workingImage, opacity: 0.062)
        case .flashPop:
            workingImage = applyFilter(
                "CIExposureAdjust",
                to: workingImage,
                parameters: [
                    kCIInputEVKey: 0.28
                ]
            )
            workingImage = applyFilter(
                "CIHighlightShadowAdjust",
                to: workingImage,
                parameters: [
                    "inputHighlightAmount": 0.68,
                    "inputShadowAmount": 0.08
                ]
            )
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 1.12,
                    kCIInputContrastKey: 1.18,
                    kCIInputBrightnessKey: 0.018
                ]
            )
            workingImage = applyVignette(to: workingImage, intensity: 0.64, radius: 0.9)
        case .toy:
            workingImage = applyFilter("CIPhotoEffectChrome", to: workingImage)
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 1.26,
                    kCIInputContrastKey: 1.12,
                    kCIInputBrightnessKey: 0.004
                ]
            )
            workingImage = applyFilter(
                "CIBloom",
                to: workingImage,
                parameters: [
                    kCIInputRadiusKey: 3.0,
                    kCIInputIntensityKey: 0.08
                ]
            )
            workingImage = applyVignette(to: workingImage, intensity: 1.05, radius: 0.85)
            workingImage = addGrain(to: workingImage, opacity: 0.035)
        case .vivid:
            workingImage = applyFilter("CIPhotoEffectChrome", to: workingImage)
            workingImage = applyFilter(
                "CIVibrance",
                to: workingImage,
                parameters: [
                    "inputAmount": 0.55
                ]
            )
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 1.15,
                    kCIInputContrastKey: 1.10,
                    kCIInputBrightnessKey: 0.004
                ]
            )
            workingImage = applyFilter(
                "CISharpenLuminance",
                to: workingImage,
                parameters: [
                    "inputSharpness": 0.22
                ]
            )
        case .chrome:
            workingImage = applyFilter("CIPhotoEffectChrome", to: workingImage)
            workingImage = applyFilter(
                "CIHighlightShadowAdjust",
                to: workingImage,
                parameters: [
                    "inputHighlightAmount": 0.74,
                    "inputShadowAmount": 0.24
                ]
            )
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 1.08,
                    kCIInputContrastKey: 1.04,
                    kCIInputBrightnessKey: 0.004
                ]
            )
        case .faded:
            workingImage = applyFilter("CIPhotoEffectFade", to: workingImage)
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 0.88,
                    kCIInputContrastKey: 0.84,
                    kCIInputBrightnessKey: 0.026
                ]
            )
            workingImage = addGrain(to: workingImage, opacity: 0.022)
        case .pastel:
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 0.86,
                    kCIInputContrastKey: 0.88,
                    kCIInputBrightnessKey: 0.024
                ]
            )
            workingImage = applyFilter(
                "CIBloom",
                to: workingImage,
                parameters: [
                    kCIInputRadiusKey: 5.0,
                    kCIInputIntensityKey: 0.10
                ]
            )
            workingImage = overlayColor(
                CIColor(red: 1.0, green: 0.73, blue: 0.88, alpha: 0.16),
                over: workingImage,
                mode: "CISoftLightBlendMode"
            )
        case .latte:
            workingImage = applyFilter(
                "CISepiaTone",
                to: workingImage,
                parameters: [
                    kCIInputIntensityKey: 0.22
                ]
            )
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 0.92,
                    kCIInputContrastKey: 0.90,
                    kCIInputBrightnessKey: 0.02
                ]
            )
            workingImage = overlayColor(
                CIColor(red: 0.92, green: 0.72, blue: 0.48, alpha: 0.14),
                over: workingImage,
                mode: "CISoftLightBlendMode"
            )
            workingImage = addGrain(to: workingImage, opacity: 0.018)
        case .mint:
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 0.98,
                    kCIInputContrastKey: 0.92,
                    kCIInputBrightnessKey: 0.016
                ]
            )
            workingImage = overlayColor(
                CIColor(red: 0.62, green: 1.0, blue: 0.78, alpha: 0.18),
                over: workingImage,
                mode: "CISoftLightBlendMode"
            )
            workingImage = applyVignette(to: workingImage, intensity: 0.18, radius: 1.6)
        case .blueHour:
            workingImage = applyFilter(
                "CITemperatureAndTint",
                to: workingImage,
                parameters: [
                    "inputNeutral": CIVector(x: 6500, y: 0),
                    "inputTargetNeutral": CIVector(x: 4300, y: -18)
                ]
            )
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 1.02,
                    kCIInputContrastKey: 0.96,
                    kCIInputBrightnessKey: 0.0
                ]
            )
            workingImage = overlayColor(
                CIColor(red: 0.24, green: 0.38, blue: 1.0, alpha: 0.16),
                over: workingImage,
                mode: "CIScreenBlendMode"
            )
            workingImage = applyVignette(to: workingImage, intensity: 0.36, radius: 1.35)
        case .noir:
            workingImage = applyFilter("CIPhotoEffectNoir", to: workingImage)
            workingImage = applyFilter(
                "CIHighlightShadowAdjust",
                to: workingImage,
                parameters: [
                    "inputHighlightAmount": 0.78,
                    "inputShadowAmount": 0.28
                ]
            )
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 0.0,
                    kCIInputContrastKey: 0.92,
                    kCIInputBrightnessKey: 0.012
                ]
            )
            workingImage = applyFilter(
                "CIGloom",
                to: workingImage,
                parameters: [
                    kCIInputRadiusKey: 5.0,
                    kCIInputIntensityKey: 0.13
                ]
            )
            workingImage = applyVignette(to: workingImage, intensity: 0.42, radius: 1.35)
        case .monoSoft:
            workingImage = applyFilter("CIPhotoEffectTonal", to: workingImage)
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 0.0,
                    kCIInputContrastKey: 0.86,
                    kCIInputBrightnessKey: 0.022
                ]
            )
            workingImage = applyFilter(
                "CIGloom",
                to: workingImage,
                parameters: [
                    kCIInputRadiusKey: 8.0,
                    kCIInputIntensityKey: 0.14
                ]
            )
            workingImage = applyVignette(to: workingImage, intensity: 0.24, radius: 1.55)
        case .holo:
            workingImage = applyFilter(
                "CIFalseColor",
                to: workingImage,
                parameters: [
                    "inputColor0": CIColor(red: 0.24, green: 0.12, blue: 0.62),
                    "inputColor1": CIColor(red: 0.66, green: 1.0, blue: 0.92)
                ]
            )
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 1.18,
                    kCIInputContrastKey: 0.96,
                    kCIInputBrightnessKey: 0.012
                ]
            )
            workingImage = applyFilter(
                "CIBloom",
                to: workingImage,
                parameters: [
                    kCIInputRadiusKey: 6.0,
                    kCIInputIntensityKey: 0.26
                ]
            )
            workingImage = overlayColor(
                CIColor(red: 1.0, green: 0.36, blue: 0.78, alpha: 0.22),
                over: workingImage,
                mode: "CISoftLightBlendMode"
            )
            workingImage = addScanlines(to: workingImage, opacity: 0.10, width: 3.0, angle: 0.0)
            workingImage = applyVignette(to: workingImage, intensity: 0.28, radius: 1.35)
        case .riso:
            workingImage = applyFilter(
                "CIColorPosterize",
                to: workingImage,
                parameters: [
                    "inputLevels": 5.0
                ]
            )
            workingImage = applyFilter(
                "CIFalseColor",
                to: workingImage,
                parameters: [
                    "inputColor0": CIColor(red: 0.08, green: 0.10, blue: 0.23),
                    "inputColor1": CIColor(red: 1.0, green: 0.38, blue: 0.66)
                ]
            )
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 1.08,
                    kCIInputContrastKey: 1.08,
                    kCIInputBrightnessKey: 0.015
                ]
            )
            workingImage = overlayDotScreen(on: workingImage, opacity: 0.20, width: 5.5, angle: 0.45)
            workingImage = addGrain(to: workingImage, opacity: 0.035)
        case .glitch:
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 1.12,
                    kCIInputContrastKey: 1.07,
                    kCIInputBrightnessKey: 0.004
                ]
            )
            workingImage = rgbSplit(workingImage, redOffset: CGSize(width: 4.0, height: 0.0), cyanOffset: CGSize(width: -3.0, height: 1.0))
            workingImage = addScanlines(to: workingImage, opacity: 0.12, width: 2.0, angle: 0.0)
            workingImage = overlayColor(
                CIColor(red: 0.24, green: 0.86, blue: 1.0, alpha: 0.16),
                over: workingImage,
                mode: "CIOverlayBlendMode"
            )
            workingImage = applyVignette(to: workingImage, intensity: 0.34, radius: 1.15)
        case .cyber:
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 1.22,
                    kCIInputContrastKey: 1.12,
                    kCIInputBrightnessKey: 0.006
                ]
            )
            workingImage = rgbSplit(
                workingImage,
                redOffset: CGSize(width: 5.0, height: -1.0),
                cyanOffset: CGSize(width: -4.0, height: 1.0)
            )
            workingImage = overlayColor(
                CIColor(red: 0.06, green: 0.98, blue: 1.0, alpha: 0.20),
                over: workingImage,
                mode: "CIOverlayBlendMode"
            )
            workingImage = overlayColor(
                CIColor(red: 1.0, green: 0.0, blue: 0.72, alpha: 0.18),
                over: workingImage,
                mode: "CISoftLightBlendMode"
            )
            workingImage = addScanlines(to: workingImage, opacity: 0.14, width: 2.5, angle: 0.0)
        case .vhs:
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 0.96,
                    kCIInputContrastKey: 1.02,
                    kCIInputBrightnessKey: 0.004
                ]
            )
            workingImage = rgbSplit(
                workingImage,
                redOffset: CGSize(width: 2.0, height: 0.0),
                cyanOffset: CGSize(width: -2.0, height: 0.0)
            )
            workingImage = addScanlines(to: workingImage, opacity: 0.16, width: 3.0, angle: 0.0)
            workingImage = overlayColor(
                CIColor(red: 0.46, green: 0.22, blue: 0.88, alpha: 0.12),
                over: workingImage,
                mode: "CISoftLightBlendMode"
            )
            workingImage = applyVignette(to: workingImage, intensity: 0.58, radius: 1.0)
            workingImage = addGrain(to: workingImage, opacity: 0.052)
        case .zine:
            workingImage = applyFilter("CIPhotoEffectNoir", to: workingImage)
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 0.0,
                    kCIInputContrastKey: 1.18,
                    kCIInputBrightnessKey: 0.025
                ]
            )
            workingImage = applyFilter(
                "CILineOverlay",
                to: workingImage,
                parameters: [
                    "inputNRNoiseLevel": 0.035,
                    "inputNRSharpness": 0.42,
                    "inputEdgeIntensity": 0.65,
                    "inputThreshold": 0.12,
                    "inputContrast": 35.0
                ]
            )
            workingImage = applyFilter(
                "CIFalseColor",
                to: workingImage,
                parameters: [
                    "inputColor0": CIColor(red: 0.05, green: 0.05, blue: 0.06),
                    "inputColor1": CIColor(red: 0.98, green: 0.92, blue: 0.80)
                ]
            )
            workingImage = overlayDotScreen(on: workingImage, opacity: 0.18, width: 4.0, angle: 0.0)
        case .comic:
            workingImage = applyFilter("CIComicEffect", to: workingImage)
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 1.05,
                    kCIInputContrastKey: 0.98,
                    kCIInputBrightnessKey: 0.018
                ]
            )
            workingImage = overlayDotScreen(on: workingImage, opacity: 0.12, width: 5.0, angle: 0.2)
        case .aura:
            workingImage = applyFilter(
                "CIColorControls",
                to: workingImage,
                parameters: [
                    kCIInputSaturationKey: 1.10,
                    kCIInputContrastKey: 0.94,
                    kCIInputBrightnessKey: 0.018
                ]
            )
            workingImage = applyFilter(
                "CIGloom",
                to: workingImage,
                parameters: [
                    kCIInputRadiusKey: 11.0,
                    kCIInputIntensityKey: 0.28
                ]
            )
            workingImage = radialAura(over: workingImage)
            workingImage = addGrain(to: workingImage, opacity: 0.018)
            workingImage = applyVignette(to: workingImage, intensity: 0.18, radius: 1.7)
        }

        guard let cgImage = context.createCGImage(workingImage, from: workingImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    private nonisolated static func applyManualAdjustments(
        _ adjustments: CreatorPhotoAdjustments,
        to image: UIImage
    ) -> UIImage? {
        guard let baseImage = orientedCIImage(from: image) else {
            return nil
        }

        var workingImage = baseImage

        if abs(adjustments.exposure) > 0.001 {
            workingImage = applyFilter(
                "CIExposureAdjust",
                to: workingImage,
                parameters: [
                    kCIInputEVKey: adjustments.exposure
                ]
            )
        }

        if abs(adjustments.warmth) > 0.001 {
            workingImage = applyFilter(
                "CITemperatureAndTint",
                to: workingImage,
                parameters: [
                    "inputNeutral": CIVector(x: 6500, y: 0),
                    "inputTargetNeutral": CIVector(
                        x: 6500 + adjustments.warmth * 1900,
                        y: adjustments.warmth * 70
                    )
                ]
            )
        }

        workingImage = applyFilter(
            "CIColorControls",
            to: workingImage,
            parameters: [
                kCIInputSaturationKey: adjustments.saturation,
                kCIInputContrastKey: adjustments.contrast,
                kCIInputBrightnessKey: adjustments.brightness
            ]
        )

        if abs(adjustments.highlights) > 0.001 || abs(adjustments.shadows) > 0.001 {
            workingImage = applyFilter(
                "CIHighlightShadowAdjust",
                to: workingImage,
                parameters: [
                    "inputHighlightAmount": clamp(1.0 - adjustments.highlights * 0.55, 0.35, 1.55),
                    "inputShadowAmount": clamp(0.25 + adjustments.shadows * 0.72, 0.0, 1.25)
                ]
            )
        }

        if adjustments.sharpen > 0.001 {
            workingImage = applyFilter(
                "CIUnsharpMask",
                to: workingImage,
                parameters: [
                    kCIInputRadiusKey: 0.35 + adjustments.sharpen * 1.25,
                    kCIInputIntensityKey: adjustments.sharpen * 0.72
                ]
            )
        }

        if adjustments.grain > 0.001 {
            workingImage = addGrain(to: workingImage, opacity: CGFloat(adjustments.grain * 0.08))
        }

        if adjustments.vignette > 0.001 {
            workingImage = applyVignette(
                to: workingImage,
                intensity: adjustments.vignette * 1.15,
                radius: max(0.75, 1.65 - adjustments.vignette * 0.55)
            )
        }

        guard let cgImage = context.createCGImage(workingImage, from: workingImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    private nonisolated static func orientedCIImage(from image: UIImage) -> CIImage? {
        if let ciImage = image.ciImage {
            return ciImage.oriented(CGImagePropertyOrientation(image.imageOrientation))
        }

        guard let cgImage = image.cgImage else {
            return nil
        }

        return CIImage(cgImage: cgImage)
            .oriented(CGImagePropertyOrientation(image.imageOrientation))
    }

    private nonisolated static func applyVignette(to image: CIImage, intensity: Double, radius: Double) -> CIImage {
        applyFilter(
            "CIVignette",
            to: image,
            parameters: [
                kCIInputIntensityKey: intensity,
                kCIInputRadiusKey: radius
            ]
        )
    }

    private nonisolated static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }

    private nonisolated static func addGrain(to image: CIImage, opacity: CGFloat) -> CIImage {
        guard let randomFilter = CIFilter(name: "CIRandomGenerator"),
              let randomImage = randomFilter.outputImage?.cropped(to: image.extent) else {
            return image
        }

        var grain = applyFilter(
            "CIColorControls",
            to: randomImage,
            parameters: [
                kCIInputSaturationKey: 0.0,
                kCIInputContrastKey: 1.35,
                kCIInputBrightnessKey: 0.0
            ]
        )

        grain = applyFilter(
            "CIColorMatrix",
            to: grain,
            parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: opacity)
            ]
        )

        return grain
            .applyingFilter(
                "CISoftLightBlendMode",
                parameters: [
                    kCIInputBackgroundImageKey: image
                ]
            )
            .cropped(to: image.extent)
    }

    private nonisolated static func overlayColor(_ color: CIColor, over image: CIImage, mode: String) -> CIImage {
        let overlay = CIImage(color: color).cropped(to: image.extent)
        return blend(overlay, over: image, mode: mode)
    }

    private nonisolated static func addScanlines(
        to image: CIImage,
        opacity: CGFloat,
        width: Double,
        angle: Double
    ) -> CIImage {
        guard let stripes = CIFilter(name: "CIStripesGenerator") else {
            return image
        }

        stripes.setValue(CIVector(x: image.extent.midX, y: image.extent.midY), forKey: "inputCenter")
        stripes.setValue(CIColor(red: 0, green: 0, blue: 0, alpha: opacity), forKey: "inputColor0")
        stripes.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 0), forKey: "inputColor1")
        stripes.setValue(width, forKey: "inputWidth")
        stripes.setValue(0.75, forKey: "inputSharpness")

        guard let stripeImage = stripes.outputImage?
            .transformed(by: CGAffineTransform(rotationAngle: angle))
            .cropped(to: image.extent) else {
            return image
        }

        return blend(stripeImage, over: image, mode: "CIMultiplyBlendMode")
    }

    private nonisolated static func overlayDotScreen(
        on image: CIImage,
        opacity: CGFloat,
        width: Double,
        angle: Double
    ) -> CIImage {
        var dots = applyFilter(
            "CIDotScreen",
            to: image,
            parameters: [
                "inputCenter": CIVector(x: image.extent.midX, y: image.extent.midY),
                "inputAngle": angle,
                "inputWidth": width,
                "inputSharpness": 0.82
            ]
        )

        dots = applyFilter(
            "CIColorMatrix",
            to: dots,
            parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: opacity)
            ]
        )

        return blend(dots, over: image, mode: "CISoftLightBlendMode")
    }

    private nonisolated static func rgbSplit(
        _ image: CIImage,
        redOffset: CGSize,
        cyanOffset: CGSize
    ) -> CIImage {
        let red = applyFilter(
            "CIColorMatrix",
            to: image,
            parameters: [
                "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
            ]
        )
        .transformed(by: CGAffineTransform(translationX: redOffset.width, y: redOffset.height))
        .cropped(to: image.extent)

        let cyan = applyFilter(
            "CIColorMatrix",
            to: image,
            parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
            ]
        )
        .transformed(by: CGAffineTransform(translationX: cyanOffset.width, y: cyanOffset.height))
        .cropped(to: image.extent)

        return blend(red, over: cyan, mode: "CIAdditionCompositing")
            .cropped(to: image.extent)
    }

    private nonisolated static func radialAura(over image: CIImage) -> CIImage {
        guard let gradient = CIFilter(name: "CIRadialGradient") else {
            return image
        }

        let radius0 = max(image.extent.width, image.extent.height) * 0.12
        let radius1 = max(image.extent.width, image.extent.height) * 0.72

        gradient.setValue(CIVector(x: image.extent.midX, y: image.extent.midY), forKey: "inputCenter")
        gradient.setValue(radius0, forKey: "inputRadius0")
        gradient.setValue(radius1, forKey: "inputRadius1")
        gradient.setValue(CIColor(red: 1.0, green: 0.34, blue: 0.72, alpha: 0.34), forKey: "inputColor0")
        gradient.setValue(CIColor(red: 0.28, green: 0.88, blue: 1.0, alpha: 0.02), forKey: "inputColor1")

        guard let aura = gradient.outputImage?.cropped(to: image.extent) else {
            return image
        }

        return blend(aura, over: image, mode: "CIScreenBlendMode")
    }

    private nonisolated static func blend(_ foreground: CIImage, over background: CIImage, mode: String) -> CIImage {
        foreground
            .applyingFilter(
                mode,
                parameters: [
                    kCIInputBackgroundImageKey: background
                ]
            )
            .cropped(to: background.extent)
    }

    private nonisolated static func applyFilter(
        _ name: String,
        to image: CIImage,
        parameters: [String: Any]
    ) -> CIImage {
        guard let filter = CIFilter(name: name) else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)

        for (key, value) in parameters where filter.inputKeys.contains(key) {
            filter.setValue(value, forKey: key)
        }

        guard let outputImage = filter.outputImage else {
            return image
        }

        return outputImage.cropped(to: image.extent)
    }

    private nonisolated static func applyFilter(_ name: String, to image: CIImage) -> CIImage {
        applyFilter(name, to: image, parameters: [:])
    }

    private nonisolated static func image(from array: MLMultiArray) -> UIImage? {
        guard let layout = MultiArrayImageLayout(array: array) else {
            return nil
        }

        let range = sampledRange(array: array)
        var rgba = [UInt8](repeating: 255, count: layout.width * layout.height * 4)

        for y in 0..<layout.height {
            for x in 0..<layout.width {
                let offset = (y * layout.width + x) * 4
                rgba[offset] = normalizedByte(value(atChannel: 0, x: x, y: y, layout: layout, array: array), range: range)
                rgba[offset + 1] = normalizedByte(value(atChannel: 1, x: x, y: y, layout: layout, array: array), range: range)
                rgba[offset + 2] = normalizedByte(value(atChannel: 2, x: x, y: y, layout: layout, array: array), range: range)
            }
        }

        let data = Data(rgba)
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                width: layout.width,
                height: layout.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: layout.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private nonisolated static func value(
        atChannel channel: Int,
        x: Int,
        y: Int,
        layout: MultiArrayImageLayout,
        array: MLMultiArray
    ) -> Double {
        let offset = layout.offset(channel: channel, x: x, y: y)

        switch array.dataType {
        case .float32:
            return Double(array.dataPointer.bindMemory(to: Float32.self, capacity: array.count)[offset])
        case .float64:
            return array.dataPointer.bindMemory(to: Double.self, capacity: array.count)[offset]
        case .float16:
            return Double(array.dataPointer.bindMemory(to: Float16.self, capacity: array.count)[offset])
        default:
            return array[[NSNumber(value: offset)]].doubleValue
        }
    }

    private nonisolated static func sampledRange(array: MLMultiArray) -> ClosedRange<Double> {
        let sampleCount = min(array.count, 8000)
        let step = max(1, array.count / max(1, sampleCount))

        var minimum = Double.greatestFiniteMagnitude
        var maximum = -Double.greatestFiniteMagnitude

        for index in stride(from: 0, to: array.count, by: step) {
            let value: Double

            switch array.dataType {
            case .float32:
                value = Double(array.dataPointer.bindMemory(to: Float32.self, capacity: array.count)[index])
            case .float64:
                value = array.dataPointer.bindMemory(to: Double.self, capacity: array.count)[index]
            case .float16:
                value = Double(array.dataPointer.bindMemory(to: Float16.self, capacity: array.count)[index])
            default:
                value = array[[NSNumber(value: index)]].doubleValue
            }

            minimum = min(minimum, value)
            maximum = max(maximum, value)
        }

        if minimum == Double.greatestFiniteMagnitude || maximum == -Double.greatestFiniteMagnitude {
            return 0...1
        }

        return minimum...maximum
    }

    private nonisolated static func normalizedByte(_ value: Double, range: ClosedRange<Double>) -> UInt8 {
        let scaled: Double

        if range.lowerBound < -0.1 && range.upperBound <= 1.1 {
            scaled = (value + 1.0) * 127.5
        } else if range.upperBound <= 1.5 {
            scaled = value * 255.0
        } else {
            scaled = value
        }

        return UInt8(max(0, min(255, scaled.rounded())))
    }
}

private struct MultiArrayImageLayout {
    let width: Int
    let height: Int
    let channelStride: Int
    let yStride: Int
    let xStride: Int
    let baseOffset: Int

    nonisolated init?(array: MLMultiArray) {
        let shape = array.shape.map(\.intValue)
        let strides = array.strides.map(\.intValue)

        switch shape.count {
        case 4 where shape[1] >= 3:
            baseOffset = 0
            height = shape[2]
            width = shape[3]
            channelStride = strides[1]
            yStride = strides[2]
            xStride = strides[3]
        case 4 where shape[3] >= 3:
            baseOffset = 0
            height = shape[1]
            width = shape[2]
            channelStride = strides[3]
            yStride = strides[1]
            xStride = strides[2]
        case 3 where shape[0] >= 3:
            baseOffset = 0
            height = shape[1]
            width = shape[2]
            channelStride = strides[0]
            yStride = strides[1]
            xStride = strides[2]
        case 3 where shape[2] >= 3:
            baseOffset = 0
            height = shape[0]
            width = shape[1]
            channelStride = strides[2]
            yStride = strides[0]
            xStride = strides[1]
        default:
            return nil
        }

        guard width > 0, height > 0 else {
            return nil
        }
    }

    nonisolated func offset(channel: Int, x: Int, y: Int) -> Int {
        baseOffset + channel * channelStride + y * yStride + x * xStride
    }
}

private extension CGImagePropertyOrientation {
    nonisolated init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
