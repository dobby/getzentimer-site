#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import Metal
import UniformTypeIdentifiers

private struct ProceduralBackgroundUniforms {
    var resolution: SIMD2<Float>
    var time: Float
    var seed: UInt32

    var paletteCount: UInt32
    var palette: (
        SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>,
        SIMD3<Float>, SIMD3<Float>, SIMD3<Float>
    )

    var gradientType: UInt32
    var gradientAngle: Float
    var gradientCenter: SIMD2<Float>

    var noiseType: UInt32
    var fbmOctaves: UInt32

    var warpStrength: Float
    var warpScale: Float
    var warpFrequency: Float
    var warpStyle: UInt32

    var colorSpread: Float
    var colorBias: Float
    var hueShift: Float

    var blobCount: UInt32
    var blobIntensity: Float
    var blobSoftness: Float
    var blobShape: UInt32
    var blobSpread: Float

    var streakCount: UInt32
    var streakAngle: Float
    var streakSpread: Float
    var streakWidth: Float
    var streakIntensity: Float
    var streakWarmth: Float

    var patternType: UInt32
    var patternScale: Float
    var patternIntensity: Float

    var grainAmount: Float
    var grainScale: Float
    var vignette: Float
    var saturation: Float
    var contrast: Float
}

private struct RenderMaterial {
    var palette: [SIMD3<Float>]

    var gradientType: UInt32 = 0
    var gradientAngle: Float = 0
    var gradientCenterX: Float = 0.5
    var gradientCenterY: Float = 0.5

    var noiseType: UInt32 = 0
    var fbmOctaves: UInt32 = 5

    var warpStrength: Float = 0.06
    var warpScale: Float = 1.4
    var warpFrequency: Float = 1.0
    var warpStyle: UInt32 = 0

    var colorSpread: Float = 1.0
    var colorBias: Float = 0.5
    var hueShift: Float = 0.0

    var blobCount: UInt32 = 3
    var blobIntensity: Float = 0.85
    var blobSoftness: Float = 0.35
    var blobShape: UInt32 = 0
    var blobSpread: Float = 1.0

    var streakCount: UInt32 = 1
    var streakAngle: Float = 0.45
    var streakSpread: Float = 0.5
    var streakWidth: Float = 0.11
    var streakIntensity: Float = 0.65
    var streakWarmth: Float = 0.45

    var patternType: UInt32 = 0
    var patternScale: Float = 1.0
    var patternIntensity: Float = 0.1

    var grainAmount: Float = 0.025
    var grainScale: Float = 1.4
    var vignette: Float = 0.18
    var saturation: Float = 1.02
    var contrast: Float = 1.05
}

private struct ThemeDefinition {
    let id: String
    let displayName: String
    let seed: UInt32
    let material: RenderMaterial
    let accentTint: SIMD3<Float>
}

private struct ImageSpec {
    let label: String
    let width: Int
    let height: Int
}

private struct ManifestThemeImage: Codable {
    let resolution: String
    let file: String
    let width: Int
    let height: Int
}

private struct ManifestTheme: Codable {
    let id: String
    let displayName: String
    let seed: UInt32
    let accentTintHex: String
    let images: [ManifestThemeImage]
}

private struct BackgroundManifest: Codable {
    let generatedAt: String
    let sourceShader: String
    let themes: [ManifestTheme]
}

private final class ProceduralBackgroundExporter {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState

    init(shaderSourcePath: URL) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw NSError(domain: "Export", code: 1, userInfo: [NSLocalizedDescriptionKey: "No Metal device available"])
        }
        guard let queue = device.makeCommandQueue() else {
            throw NSError(domain: "Export", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create Metal command queue"])
        }

        let shaderSource = try String(contentsOf: shaderSourcePath, encoding: .utf8)
        let library = try device.makeLibrary(source: shaderSource, options: nil)

        guard let vertexFunction = library.makeFunction(name: "fullscreenVertex"),
              let fragmentFunction = library.makeFunction(name: "proceduralBackground") else {
            throw NSError(domain: "Export", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing shader entry points"])
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        self.device = device
        self.queue = queue
        self.pipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    func render(material: RenderMaterial, seed: UInt32, width: Int, height: Int) throws -> CGImage {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared

        guard let texture = device.makeTexture(descriptor: descriptor),
              let commandBuffer = queue.makeCommandBuffer() else {
            throw NSError(domain: "Export", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to allocate Metal resources"])
        }

        let palette = material.palette
        var uniforms = ProceduralBackgroundUniforms(
            resolution: SIMD2(Float(width), Float(height)),
            time: 0,
            seed: seed,
            paletteCount: UInt32(palette.count),
            palette: (
                palette[safe: 0] ?? .zero,
                palette[safe: 1] ?? palette.first ?? .zero,
                palette[safe: 2] ?? palette.first ?? .zero,
                palette[safe: 3] ?? palette.first ?? .zero,
                palette[safe: 4] ?? palette.first ?? .zero,
                palette[safe: 5] ?? palette.first ?? .zero,
                palette[safe: 6] ?? palette.first ?? .zero
            ),
            gradientType: material.gradientType,
            gradientAngle: material.gradientAngle,
            gradientCenter: SIMD2(material.gradientCenterX, material.gradientCenterY),
            noiseType: material.noiseType,
            fbmOctaves: material.fbmOctaves,
            warpStrength: material.warpStrength,
            warpScale: material.warpScale,
            warpFrequency: material.warpFrequency,
            warpStyle: material.warpStyle,
            colorSpread: material.colorSpread,
            colorBias: material.colorBias,
            hueShift: material.hueShift,
            blobCount: material.blobCount,
            blobIntensity: material.blobIntensity,
            blobSoftness: material.blobSoftness,
            blobShape: material.blobShape,
            blobSpread: material.blobSpread,
            streakCount: material.streakCount,
            streakAngle: material.streakAngle,
            streakSpread: material.streakSpread,
            streakWidth: material.streakWidth,
            streakIntensity: material.streakIntensity,
            streakWarmth: material.streakWarmth,
            patternType: material.patternType,
            patternScale: material.patternScale,
            patternIntensity: material.patternIntensity,
            grainAmount: material.grainAmount,
            grainScale: material.grainScale,
            vignette: material.vignette,
            saturation: material.saturation,
            contrast: material.contrast
        )

        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store
        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            throw NSError(domain: "Export", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unable to create render encoder"])
        }

        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ProceduralBackgroundUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return try textureToCGImage(texture: texture)
    }

    private func textureToCGImage(texture: MTLTexture) throws -> CGImage {
        let width = texture.width
        let height = texture.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = bytesPerRow * height

        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: width, height: height, depth: 1))

        texture.getBytes(&pixelData, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        for index in stride(from: 0, to: totalBytes, by: 4) {
            let b = pixelData[index]
            let r = pixelData[index + 2]
            pixelData[index] = r
            pixelData[index + 2] = b
        }

        guard let provider = CGDataProvider(data: Data(pixelData) as CFData) else {
            throw NSError(domain: "Export", code: 6, userInfo: [NSLocalizedDescriptionKey: "Unable to create CGDataProvider"])
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw NSError(domain: "Export", code: 7, userInfo: [NSLocalizedDescriptionKey: "Unable to create CGImage"])
        }

        return image
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

private func rgb(_ r: Float, _ g: Float, _ b: Float) -> SIMD3<Float> {
    SIMD3(r, g, b)
}

private func hexString(_ color: SIMD3<Float>) -> String {
    let r = max(0, min(255, Int((color.x * 255).rounded())))
    let g = max(0, min(255, Int((color.y * 255).rounded())))
    let b = max(0, min(255, Int((color.z * 255).rounded())))
    return String(format: "#%02X%02X%02X", r, g, b)
}

private func writeJPEG(cgImage: CGImage, to destinationURL: URL, compression: CGFloat) throws {
    guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
        throw NSError(domain: "Export", code: 8, userInfo: [NSLocalizedDescriptionKey: "Unable to create image destination"])
    }

    let properties: CFDictionary = [kCGImageDestinationLossyCompressionQuality: compression] as CFDictionary
    CGImageDestinationAddImage(destination, cgImage, properties)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "Export", code: 9, userInfo: [NSLocalizedDescriptionKey: "Unable to finalize JPEG write"])
    }
}

private func loadCGImage(from url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

private func writePreviewGrid(from imageURLs: [URL], outputURL: URL) throws {
    let columns = 3
    let tileWidth = 640
    let tileHeight = 360
    let padding = 24
    let rows = Int(ceil(Double(imageURLs.count) / Double(columns)))

    let canvasWidth = columns * tileWidth + (columns + 1) * padding
    let canvasHeight = rows * tileHeight + (rows + 1) * padding

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: canvasWidth,
        height: canvasHeight,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "Export", code: 10, userInfo: [NSLocalizedDescriptionKey: "Unable to create preview CGContext"])
    }

    context.setFillColor(CGColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))

    for (index, url) in imageURLs.enumerated() {
        guard let image = loadCGImage(from: url) else { continue }
        let row = index / columns
        let column = index % columns

        let x = padding + column * (tileWidth + padding)
        let y = canvasHeight - padding - tileHeight - row * (tileHeight + padding)

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -8), blur: 16, color: CGColor(gray: 0, alpha: 0.4))
        context.draw(image, in: CGRect(x: x, y: y, width: tileWidth, height: tileHeight))
        context.restoreGState()
    }

    guard let outputImage = context.makeImage() else {
        throw NSError(domain: "Export", code: 11, userInfo: [NSLocalizedDescriptionKey: "Unable to produce preview CGImage"])
    }

    try writeJPEG(cgImage: outputImage, to: outputURL, compression: 0.9)
}

// MARK: - JSON Loading from SystemThemes.json

private struct JSONColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    var simd3: SIMD3<Float> {
        SIMD3(Float(red), Float(green), Float(blue))
    }
}

private struct JSONMaterial: Codable {
    let baseDark: JSONColor
    let baseMid: JSONColor
    let highlightCool: JSONColor
    let accentWarm: JSONColor
    let air: JSONColor

    let gradientType: Int?
    let gradientAngle: Float?
    let gradientCenterX: Float?
    let gradientCenterY: Float?

    let noiseType: Int?
    let fbmOctaves: Int?

    let warpStrength: Float?
    let warpScale: Float?
    let warpFrequency: Float?
    let warpStyle: Int?

    let colorSpread: Float?
    let colorBias: Float?
    let hueShift: Float?

    let blobCount: Int?
    let blobIntensity: Float?
    let blobSoftness: Float?
    let blobShape: Int?
    let blobSpread: Float?

    let streakCount: Int?
    let streakAngle: Float?
    let streakSpread: Float?
    let streakWidth: Float?
    let streakIntensity: Float?
    let streakWarmth: Float?

    let patternType: Int?
    let patternScale: Float?
    let patternIntensity: Float?

    let grainAmount: Float?
    let grainScale: Float?
    let vignette: Float?
    let saturation: Float?
    let contrast: Float?
}

private struct JSONThemeEntry: Codable {
    let id: String
    let displayName: String
    let previewSeed: UInt32
    let accentTintHex: String
    let material: JSONMaterial
}

private func loadThemes(from jsonURL: URL) throws -> [ThemeDefinition] {
    let data = try Data(contentsOf: jsonURL)
    let entries = try JSONDecoder().decode([JSONThemeEntry].self, from: data)

    return entries.map { entry in
        let m = entry.material
        var mat = RenderMaterial(
            palette: [
                m.baseDark.simd3,
                m.baseMid.simd3,
                m.highlightCool.simd3,
                m.accentWarm.simd3,
                m.air.simd3
            ]
        )

        if let v = m.gradientType { mat.gradientType = UInt32(v) }
        if let v = m.gradientAngle { mat.gradientAngle = v }
        if let v = m.gradientCenterX { mat.gradientCenterX = v }
        if let v = m.gradientCenterY { mat.gradientCenterY = v }
        if let v = m.noiseType { mat.noiseType = UInt32(v) }
        if let v = m.fbmOctaves { mat.fbmOctaves = UInt32(v) }
        if let v = m.warpStrength { mat.warpStrength = v }
        if let v = m.warpScale { mat.warpScale = v }
        if let v = m.warpFrequency { mat.warpFrequency = v }
        if let v = m.warpStyle { mat.warpStyle = UInt32(v) }
        if let v = m.colorSpread { mat.colorSpread = v }
        if let v = m.colorBias { mat.colorBias = v }
        if let v = m.hueShift { mat.hueShift = v }
        if let v = m.blobCount { mat.blobCount = UInt32(v) }
        if let v = m.blobIntensity { mat.blobIntensity = v }
        if let v = m.blobSoftness { mat.blobSoftness = v }
        if let v = m.blobShape { mat.blobShape = UInt32(v) }
        if let v = m.blobSpread { mat.blobSpread = v }
        if let v = m.streakCount { mat.streakCount = UInt32(v) }
        if let v = m.streakAngle { mat.streakAngle = v }
        if let v = m.streakSpread { mat.streakSpread = v }
        if let v = m.streakWidth { mat.streakWidth = v }
        if let v = m.streakIntensity { mat.streakIntensity = v }
        if let v = m.streakWarmth { mat.streakWarmth = v }
        if let v = m.patternType { mat.patternType = UInt32(v) }
        if let v = m.patternScale { mat.patternScale = v }
        if let v = m.patternIntensity { mat.patternIntensity = v }
        if let v = m.grainAmount { mat.grainAmount = v }
        if let v = m.grainScale { mat.grainScale = v }
        if let v = m.vignette { mat.vignette = v }
        if let v = m.saturation { mat.saturation = v }
        if let v = m.contrast { mat.contrast = v }

        // Parse accent tint from hex
        let hex = entry.accentTintHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let accentTint = SIMD3<Float>(
            Float((rgb >> 16) & 0xFF) / 255.0,
            Float((rgb >> 8) & 0xFF) / 255.0,
            Float(rgb & 0xFF) / 255.0
        )

        return ThemeDefinition(
            id: entry.id,
            displayName: entry.displayName,
            seed: entry.previewSeed,
            material: mat,
            accentTint: accentTint
        )
    }
}

private func run() throws {
    let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let shaderURL = projectRoot.appendingPathComponent("ZenTimer/Shaders/ProceduralBackground.metal")
    let outputDirectory = projectRoot.appendingPathComponent("site/assets/img/backgrounds")

    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    let exporter = try ProceduralBackgroundExporter(shaderSourcePath: shaderURL)
    let jsonURL = projectRoot.appendingPathComponent("ZenTimer/Resources/SystemThemes.json")
    let themes = try loadThemes(from: jsonURL)
    let imageSpecs = [
        ImageSpec(label: "3840x2160", width: 3840, height: 2160),
        ImageSpec(label: "2560x1440", width: 2560, height: 1440),
        ImageSpec(label: "1600x900", width: 1600, height: 900)
    ]

    var manifestThemes: [ManifestTheme] = []
    var previewSourceURLs: [URL] = []

    for theme in themes {
        print("Rendering \(theme.displayName)…")
        var manifestImages: [ManifestThemeImage] = []

        for spec in imageSpecs {
            let image = try exporter.render(
                material: theme.material,
                seed: theme.seed,
                width: spec.width,
                height: spec.height
            )

            let fileName = "\(theme.id)-\(spec.label).jpg"
            let fileURL = outputDirectory.appendingPathComponent(fileName)
            try writeJPEG(cgImage: image, to: fileURL, compression: 0.88)

            if spec.label == "1600x900" {
                previewSourceURLs.append(fileURL)
            }

            manifestImages.append(
                ManifestThemeImage(
                    resolution: spec.label,
                    file: "assets/img/backgrounds/\(fileName)",
                    width: spec.width,
                    height: spec.height
                )
            )
        }

        manifestThemes.append(
            ManifestTheme(
                id: theme.id,
                displayName: theme.displayName,
                seed: theme.seed,
                accentTintHex: hexString(theme.accentTint),
                images: manifestImages
            )
        )
    }

    let manifest = BackgroundManifest(
        generatedAt: ISO8601DateFormatter().string(from: Date()),
        sourceShader: "ZenTimer/Shaders/ProceduralBackground.metal",
        themes: manifestThemes
    )

    let manifestURL = outputDirectory.appendingPathComponent("manifest.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let manifestData = try encoder.encode(manifest)
    try manifestData.write(to: manifestURL, options: .atomic)

    let previewURL = outputDirectory.appendingPathComponent("preview-grid.jpg")
    try writePreviewGrid(from: previewSourceURLs, outputURL: previewURL)

    print("Done. Wrote backgrounds, manifest, and preview grid to \(outputDirectory.path)")
}

do {
    try run()
} catch {
    fputs("Export failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
