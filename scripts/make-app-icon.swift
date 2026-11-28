// Uso: swiftc -O scripts/make-app-icon.swift -o /tmp/make-app-icon && /tmp/make-app-icon Design/freesla-logo-white.png Design/freesla-app-icon-1024.png
// Genera el icono maestro de 1024x1024 (cuadrado redondeado oscuro + logo blanco). Los tamaños se sacan con sips (ver README).
import AppKit
import CoreGraphics

// Genera el icono maestro de 1024x1024: cuadrado redondeado oscuro + logo blanco.
let logoPath = CommandLine.arguments[1], outPath = CommandLine.arguments[2]
let size = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// Plantilla de macOS: el cuadrado ocupa 824 de 1024 (margen para la sombra).
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

// Sombra suave bajo el icono.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: CGColor(gray: 0, alpha: 0.45))
ctx.addPath(shape); ctx.setFillColor(CGColor(gray: 0.1, alpha: 1)); ctx.fillPath()
ctx.restoreGState()

// Fondo: degradado vertical gris muy oscuro -> casi negro.
ctx.saveGState()
ctx.addPath(shape); ctx.clip()
let grad = CGGradient(colorsSpace: cs, colors: [CGColor(red: 0.20, green: 0.20, blue: 0.23, alpha: 1),
                                                CGColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
ctx.restoreGState()

// Filo de luz interior en el borde.
ctx.saveGState()
ctx.addPath(shape); ctx.clip()
ctx.addPath(shape); ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.18)); ctx.setLineWidth(4); ctx.strokePath()
ctx.restoreGState()

// Logo blanco centrado (~62 % del cuadrado).
let logo = NSImage(contentsOfFile: logoPath)!
var rect = CGRect(x: 0, y: 0, width: logo.size.width, height: logo.size.height)
let cg = logo.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
let side: CGFloat = 540
ctx.draw(cg, in: CGRect(x: 512 - side / 2, y: 512 - side / 2, width: side, height: side))

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
