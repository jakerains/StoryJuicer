"use client";

import { useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { track } from "@vercel/analytics";
import { DownloadButton } from "./DownloadButton";
import { FeedbackModal } from "./FeedbackModal";
import { latestVersion } from "@/lib/changelog";

export function Footer() {
  const version = latestVersion();
  const [feedbackOpen, setFeedbackOpen] = useState(false);

  return (
    <footer className="relative border-t border-transparent">
      {/* Gradient top border */}
      <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-sj-border to-transparent" />

      <div className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <div className="flex flex-col items-center gap-8 md:flex-row md:justify-between">
          {/* Branding */}
          <div className="flex flex-col items-center gap-3 md:items-start">
            <div className="flex items-center gap-2.5">
              <Image
                src="/app-icon.png"
                alt="StoryFox"
                width={28}
                height={28}
                className="rounded-lg"
              />
              <span className="font-serif text-base font-bold text-sj-text">
                StoryFox
              </span>
            </div>
            <a
              href="https://jakerains.com"
              target="_blank"
              rel="noopener noreferrer"
              className="text-sm text-sj-muted transition-colors hover:text-sj-coral"
            >
              Made with love by Jake Rains
            </a>
          </div>

          {/* Links */}
          <div className="flex flex-col items-center gap-3 md:items-center">
            <div className="flex flex-wrap items-center justify-center gap-3">
              <a
                href="https://github.com/jakerains/StoryFox"
                target="_blank"
                rel="noopener noreferrer"
                onClick={() => track("GitHub Click", { location: "footer" })}
                className="inline-flex items-center gap-2 rounded-full border border-sj-border/50 bg-[var(--sj-card)]/60 px-4 py-2 text-sm font-medium text-sj-secondary backdrop-blur-sm transition-all duration-200 hover:border-sj-coral/40 hover:text-sj-coral"
              >
                <svg className="h-4 w-4" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z" />
                </svg>
                View on GitHub
              </a>
              <Link
                href="/changelog"
                onClick={() => track("Changelog Click", { location: "footer" })}
                className="inline-flex items-center gap-2 rounded-full border border-sj-border/50 bg-[var(--sj-card)]/60 px-4 py-2 text-sm font-medium text-sj-secondary backdrop-blur-sm transition-all duration-200 hover:border-sj-coral/40 hover:text-sj-coral"
              >
                <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                </svg>
                Changelog
              </Link>
              <button
                onClick={() => {
                  track("Feedback Click", { location: "footer" });
                  setFeedbackOpen(true);
                }}
                className="inline-flex items-center gap-2 rounded-full border border-sj-border/50 bg-[var(--sj-card)]/60 px-4 py-2 text-sm font-medium text-sj-secondary backdrop-blur-sm transition-all duration-200 hover:border-sj-coral/40 hover:text-sj-coral"
              >
                <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M7.5 8.25h9m-9 3H12m-9.75 1.51c0 1.6 1.123 2.994 2.707 3.227 1.129.166 2.27.293 3.423.379.35.026.67.21.865.501L12 21l2.755-4.133a1.14 1.14 0 01.865-.501 48.172 48.172 0 003.423-.379c1.584-.233 2.707-1.626 2.707-3.228V6.741c0-1.602-1.123-2.995-2.707-3.228A48.394 48.394 0 0012 3c-2.392 0-4.744.175-7.043.513C3.373 3.746 2.25 5.14 2.25 6.741v6.018z" />
                </svg>
                Share Feedback
              </button>
              <span className="rounded-full bg-sj-gold/10 px-2.5 py-0.5 text-xs font-medium text-sj-gold">
                v{version}
              </span>
            </div>
          </div>

          {/* Download CTA */}
          <div className="flex flex-col items-center gap-2 md:items-end">
            <DownloadButton size="sm" location="footer" />
          </div>
        </div>
      </div>
      <FeedbackModal open={feedbackOpen} onClose={() => setFeedbackOpen(false)} />
    </footer>
  );
}
