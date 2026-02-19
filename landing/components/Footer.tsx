"use client";

import Image from "next/image";
import { DownloadButton } from "./DownloadButton";

export function Footer() {
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
                alt="StoryJuicer"
                width={28}
                height={28}
                className="rounded-lg"
              />
              <span className="font-serif text-base font-bold text-sj-text">
                StoryJuicer
              </span>
            </div>
            <p className="text-sm text-sj-muted">
              Made with love by Jake Rains
            </p>
          </div>

          {/* Links */}
          <div className="flex flex-col items-center gap-3 md:items-center">
            <div className="flex items-center gap-4">
              <a
                href="https://github.com/jakerains/StoryJuicer"
                target="_blank"
                rel="noopener noreferrer"
                className="text-sm font-medium text-sj-secondary transition-colors hover:text-sj-coral"
              >
                GitHub
              </a>
              <span className="text-sj-border">·</span>
              <span className="rounded-full bg-sj-gold/10 px-2.5 py-0.5 text-xs font-medium text-sj-gold">
                v1.0.2
              </span>
            </div>
          </div>

          {/* Download CTA */}
          <div className="flex flex-col items-center gap-2 md:items-end">
            <DownloadButton size="sm" />
          </div>
        </div>
      </div>
    </footer>
  );
}
