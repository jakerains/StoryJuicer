const fs = require("fs");
const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
        Header, Footer, AlignmentType, LevelFormat, HeadingLevel,
        BorderStyle, WidthType, ShadingType, PageNumber, PageBreak } = require("docx");

// Theme colors
const CORAL = "D4654A";
const DARK_BG = "2C2420";
const WARM_CREAM = "F5F0E8";
const SECTION_BG = "E8E0D4";
const LIGHT_ACCENT = "F0E6D8";
const MUTED = "666666";

const tableBorder = { style: BorderStyle.SINGLE, size: 1, color: "CCCCCC" };
const cellBorders = { top: tableBorder, bottom: tableBorder, left: tableBorder, right: tableBorder };

function cmdRow(cmd, desc, details) {
  return new TableRow({
    children: [
      new TableCell({
        borders: cellBorders,
        width: { size: 2800, type: WidthType.DXA },
        shading: { fill: "F8F4EE", type: ShadingType.CLEAR },
        children: [new Paragraph({
          spacing: { before: 60, after: 60 },
          children: [new TextRun({ text: cmd, bold: true, font: "Courier New", size: 20, color: CORAL })]
        })]
      }),
      new TableCell({
        borders: cellBorders,
        width: { size: 2600, type: WidthType.DXA },
        children: [new Paragraph({
          spacing: { before: 60, after: 60 },
          children: [new TextRun({ text: desc, size: 20 })]
        })]
      }),
      new TableCell({
        borders: cellBorders,
        width: { size: 3960, type: WidthType.DXA },
        children: [new Paragraph({
          spacing: { before: 60, after: 60 },
          children: [new TextRun({ text: details, size: 18, color: MUTED, italics: true })]
        })]
      })
    ]
  });
}

function headerRow() {
  return new TableRow({
    tableHeader: true,
    children: [
      new TableCell({
        borders: cellBorders,
        width: { size: 2800, type: WidthType.DXA },
        shading: { fill: CORAL, type: ShadingType.CLEAR },
        children: [new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { before: 80, after: 80 },
          children: [new TextRun({ text: "Command", bold: true, size: 22, color: "FFFFFF", font: "Arial" })]
        })]
      }),
      new TableCell({
        borders: cellBorders,
        width: { size: 2600, type: WidthType.DXA },
        shading: { fill: CORAL, type: ShadingType.CLEAR },
        children: [new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { before: 80, after: 80 },
          children: [new TextRun({ text: "Description", bold: true, size: 22, color: "FFFFFF", font: "Arial" })]
        })]
      }),
      new TableCell({
        borders: cellBorders,
        width: { size: 3960, type: WidthType.DXA },
        shading: { fill: CORAL, type: ShadingType.CLEAR },
        children: [new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { before: 80, after: 80 },
          children: [new TextRun({ text: "Details", bold: true, size: 22, color: "FFFFFF", font: "Arial" })]
        })]
      })
    ]
  });
}

const doc = new Document({
  styles: {
    default: { document: { run: { font: "Arial", size: 22 } } },
    paragraphStyles: [
      { id: "Title", name: "Title", basedOn: "Normal",
        run: { size: 56, bold: true, color: CORAL, font: "Arial" },
        paragraph: { spacing: { before: 0, after: 80 }, alignment: AlignmentType.CENTER } },
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 32, bold: true, color: DARK_BG, font: "Arial" },
        paragraph: { spacing: { before: 360, after: 160 }, outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 26, bold: true, color: CORAL, font: "Arial" },
        paragraph: { spacing: { before: 240, after: 120 }, outlineLevel: 1 } },
    ]
  },
  numbering: {
    config: [
      { reference: "bullet-list",
        levels: [{ level: 0, format: LevelFormat.BULLET, text: "\u2022", alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 720, hanging: 360 } } } }] },
      { reference: "num-pipeline",
        levels: [{ level: 0, format: LevelFormat.DECIMAL, text: "%1.", alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 720, hanging: 360 } } } }] },
      { reference: "num-prereqs",
        levels: [{ level: 0, format: LevelFormat.DECIMAL, text: "%1.", alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 720, hanging: 360 } } } }] },
    ]
  },
  sections: [{
    properties: {
      page: {
        margin: { top: 1200, right: 1200, bottom: 1200, left: 1200 },
        pageNumbers: { start: 1 }
      }
    },
    headers: {
      default: new Header({ children: [new Paragraph({
        alignment: AlignmentType.RIGHT,
        children: [
          new TextRun({ text: "StoryFox Build Guide", italics: true, size: 18, color: MUTED })
        ]
      })] })
    },
    footers: {
      default: new Footer({ children: [new Paragraph({
        alignment: AlignmentType.CENTER,
        children: [
          new TextRun({ text: "Page ", size: 18, color: MUTED }),
          new TextRun({ children: [PageNumber.CURRENT], size: 18, color: MUTED }),
          new TextRun({ text: " of ", size: 18, color: MUTED }),
          new TextRun({ children: [PageNumber.TOTAL_PAGES], size: 18, color: MUTED })
        ]
      })] })
    },
    children: [
      // Title
      new Paragraph({ heading: HeadingLevel.TITLE, children: [new TextRun("StoryFox")] }),
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { after: 80 },
        children: [new TextRun({ text: "Build & Command Guide", size: 32, color: DARK_BG })]
      }),
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { after: 400 },
        children: [new TextRun({ text: "All Makefile commands for building, running, and distributing StoryFox", size: 20, color: MUTED, italics: true })]
      }),

      // Quick Reference
      new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("Quick Reference")] }),
      new Paragraph({
        spacing: { after: 200 },
        children: [new TextRun({ text: "StoryFox uses a Makefile to wrap all build, run, and distribution commands. Every command is invoked as ", size: 22 }),
                   new TextRun({ text: "make <target>", bold: true, font: "Courier New", size: 20, color: CORAL }),
                   new TextRun({ text: " from the project root directory.", size: 22 })]
      }),

      new Table({
        columnWidths: [2800, 2600, 3960],
        rows: [
          headerRow(),
          cmdRow("make help", "List all commands", "Prints a summary of every available make target."),
          cmdRow("make doctor", "Check toolchain", "Runs scripts/doctor.sh to verify Xcode, XcodeGen, and SDK readiness."),
          cmdRow("make generate", "Regenerate project", "Runs xcodegen generate to rebuild StoryFox.xcodeproj from project.yml."),
          cmdRow("make build", "Build Debug (macOS)", "Generates project and compiles a Debug build for macOS."),
          cmdRow("make run", "Build & run Debug", "Builds Debug and opens the app. Your daily driver for development."),
          cmdRow("make build-release", "Build Release (macOS)", "Compiles an optimized Release build for macOS."),
          cmdRow("make run-release", "Build & run Release", "Builds Release and opens the app. Test production behavior locally."),
          cmdRow("make build-ios", "Build Debug (iOS)", "Generates project and builds for iOS Simulator (iPhone 16 Pro, iOS 26)."),
          cmdRow("make run-ios", "Build & run iOS Sim", "Builds, boots the Simulator, installs the app, and launches it."),
          cmdRow("make dmg", "Full distribution", "Signs, notarizes, staples, and packages a DMG for public distribution."),
          cmdRow("make clean", "Clean build artifacts", "Runs xcodebuild clean to remove derived data for StoryFox."),
          cmdRow("make app-path", "Print .app path", "Outputs the built Debug .app bundle path (useful for scripting)."),
          cmdRow("make purge-image-cache", "Clear Diffusers cache", "Removes locally cached Diffusers model and runtime data."),
        ]
      }),

      // Development
      new Paragraph({ children: [new PageBreak()] }),
      new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("Development Commands")] }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("make build")] }),
      new Paragraph({
        spacing: { after: 100 },
        children: [new TextRun("Regenerates the Xcode project from "),
                   new TextRun({ text: "project.yml", font: "Courier New", size: 20 }),
                   new TextRun(" using XcodeGen, then compiles a Debug build for macOS. This is the safest way to build after adding, moving, or renaming Swift files.")]
      }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("make run")] }),
      new Paragraph({
        spacing: { after: 100 },
        children: [new TextRun("Your everyday command. Builds the Debug configuration and immediately opens the app. Equivalent to pressing "),
                   new TextRun({ text: "Cmd+R", bold: true }),
                   new TextRun(" in Xcode but from the terminal.")]
      }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("make build-release / make run-release")] }),
      new Paragraph({
        spacing: { after: 100 },
        children: [new TextRun("Same as above but with Release optimizations enabled. Use these to test production behavior (optimized code paths, stripped debug info) without going through the full distribution pipeline.")]
      }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("make generate")] }),
      new Paragraph({
        spacing: { after: 100 },
        children: [new TextRun("Runs "),
                   new TextRun({ text: "xcodegen generate", font: "Courier New", size: 20 }),
                   new TextRun(" to rebuild the "),
                   new TextRun({ text: ".xcodeproj", font: "Courier New", size: 20 }),
                   new TextRun(" from "),
                   new TextRun({ text: "project.yml", font: "Courier New", size: 20 }),
                   new TextRun(". Required after adding, moving, or renaming Swift files. Note: XcodeGen overwrites the entitlements file, so sandbox permissions are automatically restored by the build scripts.")]
      }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("make clean")] }),
      new Paragraph({
        spacing: { after: 100 },
        children: [new TextRun("Runs "),
                   new TextRun({ text: "xcodebuild clean", font: "Courier New", size: 20 }),
                   new TextRun(" to remove all build artifacts for the StoryFox scheme. Useful when you hit strange caching issues or want a fresh start.")]
      }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("make app-path")] }),
      new Paragraph({
        spacing: { after: 100 },
        children: [new TextRun("Prints the absolute path to the built Debug "),
                   new TextRun({ text: ".app", font: "Courier New", size: 20 }),
                   new TextRun(" bundle. Handy for scripting, running the app from the terminal, or passing the path to other tools.")]
      }),

      // iOS
      new Paragraph({ children: [new PageBreak()] }),
      new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("iOS Simulator Commands")] }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("make build-ios")] }),
      new Paragraph({
        spacing: { after: 100 },
        children: [new TextRun("Generates the Xcode project and builds the "),
                   new TextRun({ text: "StoryFox-iOS", font: "Courier New", size: 20 }),
                   new TextRun(" scheme for iOS Simulator (targeting iPhone 16 Pro, iOS 26.0). Does not launch the Simulator.")]
      }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("make run-ios")] }),
      new Paragraph({
        spacing: { after: 100 },
        children: [new TextRun("The full iOS development workflow in one command:")]
      }),
      new Paragraph({
        numbering: { reference: "num-pipeline", level: 0 },
        children: [new TextRun("Builds the iOS Debug target (same as "),
                   new TextRun({ text: "make build-ios", font: "Courier New", size: 20 }),
                   new TextRun(")")]
      }),
      new Paragraph({
        numbering: { reference: "num-pipeline", level: 0 },
        children: [new TextRun("Boots the iPhone 16 Pro simulator (if not already running)")]
      }),
      new Paragraph({
        numbering: { reference: "num-pipeline", level: 0 },
        children: [new TextRun("Opens the Simulator app")]
      }),
      new Paragraph({
        numbering: { reference: "num-pipeline", level: 0 },
        children: [new TextRun("Installs the built "),
                   new TextRun({ text: ".app", font: "Courier New", size: 20 }),
                   new TextRun(" on the booted device")]
      }),
      new Paragraph({
        numbering: { reference: "num-pipeline", level: 0 },
        spacing: { after: 200 },
        children: [new TextRun("Launches StoryFox in the Simulator")]
      }),
      new Paragraph({
        spacing: { after: 100 },
        children: [new TextRun({ text: "Note: ", bold: true }),
                   new TextRun("The iOS target shares all generation logic, models, and utilities with the macOS target. Only the view layer differs (iOS-specific views in "),
                   new TextRun({ text: "iOS/Views/", font: "Courier New", size: 20 }),
                   new TextRun(").")]
      }),

      // Distribution
      new Paragraph({ children: [new PageBreak()] }),
      new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("Distribution")] }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("make dmg")] }),
      new Paragraph({
        spacing: { after: 100 },
        children: [new TextRun("The complete distribution pipeline. Produces a signed, notarized, stapled DMG at "),
                   new TextRun({ text: "dist/StoryFox.dmg", font: "Courier New", size: 20, bold: true }),
                   new TextRun(" ready for public download. The 7-step pipeline:")]
      }),

      new Table({
        columnWidths: [1200, 8160],
        rows: [
          new TableRow({
            tableHeader: true,
            children: [
              new TableCell({
                borders: cellBorders,
                width: { size: 1200, type: WidthType.DXA },
                shading: { fill: DARK_BG, type: ShadingType.CLEAR },
                children: [new Paragraph({
                  alignment: AlignmentType.CENTER,
                  spacing: { before: 60, after: 60 },
                  children: [new TextRun({ text: "Step", bold: true, size: 20, color: "FFFFFF" })]
                })]
              }),
              new TableCell({
                borders: cellBorders,
                width: { size: 8160, type: WidthType.DXA },
                shading: { fill: DARK_BG, type: ShadingType.CLEAR },
                children: [new Paragraph({
                  spacing: { before: 60, after: 60 },
                  children: [new TextRun({ text: "Action", bold: true, size: 20, color: "FFFFFF" })]
                })]
              })
            ]
          }),
          ...[ ["1/7", "Prepare output directory \u2014 creates dist/export/, cleans previous artifacts"],
               ["2/7", "Regenerate Xcode project with xcodegen and restore entitlements (network, JIT, unsigned memory)"],
               ["3/7", "Build Release archive with Developer ID signing and hardened runtime"],
               ["4/7", "Export signed .app using ExportOptions plist (developer-id method, manual signing)"],
               ["5/7", "Notarize the .app with Apple (ditto zip, notarytool submit --wait)"],
               ["6/7", "Staple notarization ticket to the .app bundle"],
               ["7/7", "Create DMG with drag-to-Applications symlink, then notarize and staple the DMG itself"]
          ].map(([step, action]) => new TableRow({
            children: [
              new TableCell({
                borders: cellBorders,
                width: { size: 1200, type: WidthType.DXA },
                shading: { fill: "F8F4EE", type: ShadingType.CLEAR },
                children: [new Paragraph({
                  alignment: AlignmentType.CENTER,
                  spacing: { before: 60, after: 60 },
                  children: [new TextRun({ text: step, bold: true, size: 20, color: CORAL })]
                })]
              }),
              new TableCell({
                borders: cellBorders,
                width: { size: 8160, type: WidthType.DXA },
                children: [new Paragraph({
                  spacing: { before: 60, after: 60 },
                  children: [new TextRun({ text: action, size: 20 })]
                })]
              })
            ]
          }))
        ]
      }),

      new Paragraph({ spacing: { before: 240 }, children: [] }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("Prerequisites for make dmg")] }),
      new Paragraph({
        spacing: { after: 80 },
        children: [new TextRun("Before running the distribution pipeline for the first time, set up notarization credentials:")]
      }),
      new Paragraph({
        numbering: { reference: "num-prereqs", level: 0 },
        children: [new TextRun("A valid "),
                   new TextRun({ text: "Developer ID Application", bold: true }),
                   new TextRun(" signing certificate in your Keychain")]
      }),
      new Paragraph({
        numbering: { reference: "num-prereqs", level: 0 },
        children: [new TextRun("An app-specific password for your Apple ID")]
      }),
      new Paragraph({
        numbering: { reference: "num-prereqs", level: 0 },
        spacing: { after: 100 },
        children: [new TextRun("Stored credentials via: "),
                   new TextRun({ text: "xcrun notarytool store-credentials \"StoryFox-Notarize\"", font: "Courier New", size: 18 })]
      }),

      new Paragraph({
        spacing: { after: 100 },
        children: [
          new TextRun({ text: "Signing Identity: ", bold: true }),
          new TextRun({ text: "Developer ID Application: Jacob RAINS (47347VQHQV)", font: "Courier New", size: 18 })
        ]
      }),
      new Paragraph({
        spacing: { after: 200 },
        children: [
          new TextRun({ text: "Notarization Profile: ", bold: true }),
          new TextRun({ text: "StoryFox-Notarize", font: "Courier New", size: 18 }),
          new TextRun(" (stored in macOS Keychain)")
        ]
      }),

      // Utilities
      new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("Utilities")] }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("make doctor")] }),
      new Paragraph({
        spacing: { after: 100 },
        children: [new TextRun("Runs "),
                   new TextRun({ text: "scripts/doctor.sh", font: "Courier New", size: 20 }),
                   new TextRun(" to check that your local toolchain is ready: Xcode version, XcodeGen installation, macOS SDK availability, and other prerequisites. Run this first if builds fail unexpectedly.")]
      }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("make purge-image-cache")] }),
      new Paragraph({
        spacing: { after: 100 },
        children: [new TextRun("Removes locally cached Diffusers runtime and model data. If local image generation is acting strangely or you want to reclaim disk space, this clears the cache so models will be re-downloaded on next use.")]
      }),

      new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun("make help")] }),
      new Paragraph({
        spacing: { after: 200 },
        children: [new TextRun("Prints a compact summary of all available make targets with one-line descriptions. This is the default target \u2014 running just "),
                   new TextRun({ text: "make", font: "Courier New", size: 20, bold: true }),
                   new TextRun(" with no arguments will display the help text.")]
      }),

      // Cheat sheet
      new Paragraph({ children: [new PageBreak()] }),
      new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("Cheat Sheet")] }),
      new Paragraph({
        spacing: { after: 200 },
        children: [new TextRun({ text: "Common workflows at a glance:", italics: true, color: MUTED })]
      }),

      new Table({
        columnWidths: [4000, 5360],
        rows: [
          new TableRow({
            tableHeader: true,
            children: [
              new TableCell({
                borders: cellBorders,
                width: { size: 4000, type: WidthType.DXA },
                shading: { fill: CORAL, type: ShadingType.CLEAR },
                children: [new Paragraph({
                  alignment: AlignmentType.CENTER,
                  spacing: { before: 80, after: 80 },
                  children: [new TextRun({ text: "I want to...", bold: true, size: 22, color: "FFFFFF" })]
                })]
              }),
              new TableCell({
                borders: cellBorders,
                width: { size: 5360, type: WidthType.DXA },
                shading: { fill: CORAL, type: ShadingType.CLEAR },
                children: [new Paragraph({
                  alignment: AlignmentType.CENTER,
                  spacing: { before: 80, after: 80 },
                  children: [new TextRun({ text: "Run this", bold: true, size: 22, color: "FFFFFF" })]
                })]
              })
            ]
          }),
          ...[
            ["Develop and test on my Mac", "make run"],
            ["Develop and test on iOS Simulator", "make run-ios"],
            ["Test release performance locally", "make run-release"],
            ["Ship a DMG for distribution", "make dmg"],
            ["Check if my tools are set up", "make doctor"],
            ["Start fresh after weird errors", "make clean && make run"],
            ["Add a new Swift file and rebuild", "make generate && make build"],
            ["Free up disk space from models", "make purge-image-cache"],
          ].map(([want, cmd]) => new TableRow({
            children: [
              new TableCell({
                borders: cellBorders,
                width: { size: 4000, type: WidthType.DXA },
                children: [new Paragraph({
                  spacing: { before: 60, after: 60 },
                  children: [new TextRun({ text: want, size: 20 })]
                })]
              }),
              new TableCell({
                borders: cellBorders,
                width: { size: 5360, type: WidthType.DXA },
                shading: { fill: "F8F4EE", type: ShadingType.CLEAR },
                children: [new Paragraph({
                  spacing: { before: 60, after: 60 },
                  children: [new TextRun({ text: cmd, bold: true, font: "Courier New", size: 20, color: CORAL })]
                })]
              })
            ]
          }))
        ]
      }),

      new Paragraph({ spacing: { before: 400 }, children: [] }),
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { after: 100 },
        children: [new TextRun({ text: "Generated for StoryFox", size: 18, color: MUTED, italics: true })]
      }),
      new Paragraph({
        alignment: AlignmentType.CENTER,
        children: [new TextRun({ text: "macOS 26 + iOS 26 \u2022 Apple Silicon", size: 18, color: MUTED, italics: true })]
      }),
    ]
  }]
});

const outputPath = process.argv[2] || "StoryFox_Build_Guide.docx";
Packer.toBuffer(doc).then(buffer => {
  fs.writeFileSync(outputPath, buffer);
  console.log(`Document saved to: ${outputPath}`);
});
