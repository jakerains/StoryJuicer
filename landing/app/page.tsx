import { Navigation } from "@/components/Navigation";
import { Hero } from "@/components/Hero";
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
            softwareVersion: "1.3.1",
            downloadUrl:
              "https://github.com/jakerains/StoryFox/releases/latest/download/StoryFox.dmg",
          }),
        }}
      />
      <Navigation />
      <main>
        <Hero />
        <HowItWorks />
        <Features />
        <HuggingFaceSection />
        <StylesShowcase />
        <BookFormats />
        <Requirements />
        <SafetyDisclaimer />
      </main>
      <Footer />
    </>
  );
}
