import type { Metadata } from "next";
import { Navigation } from "@/components/Navigation";
import { ChangelogTimeline } from "@/components/ChangelogTimeline";
import { Footer } from "@/components/Footer";

export const metadata: Metadata = {
  title: "Changelog — StoryJuicer",
  description:
    "See what's new in each release of StoryJuicer — the AI-powered illustrated storybook creator for Mac.",
};

export default function ChangelogPage() {
  return (
    <main className="min-h-screen bg-[var(--sj-bg-top)]">
      <Navigation />
      <div className="mx-auto max-w-3xl px-4 pb-24 pt-28 sm:px-6 lg:px-8">
        <h1 className="font-serif text-4xl font-bold text-sj-text sm:text-5xl">
          Changelog
        </h1>
        <p className="mt-3 text-lg text-sj-secondary">
          A history of everything new, fixed, and improved in StoryJuicer.
        </p>
        <ChangelogTimeline />
      </div>
      <Footer />
    </main>
  );
}
