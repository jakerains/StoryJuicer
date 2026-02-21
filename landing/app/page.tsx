import { Navigation } from "@/components/Navigation";
import { Hero } from "@/components/Hero";
import { AppPreview } from "@/components/AppPreview";
import { HowItWorks } from "@/components/HowItWorks";
import { Features } from "@/components/Features";
import { HuggingFaceSection } from "@/components/HuggingFaceSection";
import { StylesShowcase } from "@/components/StylesShowcase";
import { BookFormats } from "@/components/BookFormats";
import { Requirements } from "@/components/Requirements";
import { SafetyDisclaimer } from "@/components/SafetyDisclaimer";
import { Footer } from "@/components/Footer";

export default function Page() {
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "SoftwareApplication",
            name: "StoryFox",
            applicationCategory: "UtilitiesApplication",
            operatingSystem: "macOS 26",
            offers: {
              "@type": "Offer",
              price: "0",
              priceCurrency: "USD",
            },
            description:
              "AI-powered illustrated children's storybooks — on your device. Generate complete storybooks with text, illustrations, and print-ready PDF export.",
            author: { "@type": "Person", name: "Jake Rains" },
            softwareVersion: "1.7.0",
            downloadUrl:
              "https://github.com/jakerains/StoryFox/releases/latest/download/StoryFox.dmg",
          }),
        }}
      />
      <Navigation />
      <main>
        {/* Above the parallax window — opaque so it slides over the pinned preview */}
        <div className="relative z-10 bg-[var(--sj-bg-top)]">
          <Hero />
        </div>

        {/* Parallax window — pinned behind, revealed as hero scrolls away */}
        <AppPreview />

        {/* Below the parallax window — opaque so it slides over the pinned preview */}
        <div className="relative z-10 bg-[var(--sj-bg-top)]">
          <HowItWorks />
          <Features />
          <HuggingFaceSection />
          <StylesShowcase />
          <BookFormats />
          <Requirements />
          <SafetyDisclaimer />
        </div>
      </main>
      {/* Footer also needs opaque bg + z-10 so it slides over the fixed image */}
      <div className="relative z-10 bg-[var(--sj-bg-top)]">
        <Footer />
      </div>
    </>
  );
}
