"use client";

import { useEffect, useState } from "react";
import { track } from "@vercel/analytics";

const DMG_URL =
  "https://github.com/jakerains/StoryFox/releases/latest/download/StoryFox.dmg";
const GITHUB_URL = "https://github.com/jakerains/StoryFox";

function AppleIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="currentColor"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
    </svg>
  );
}

function GitHubIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="currentColor"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0 1 12 6.844a9.59 9.59 0 0 1 2.504.337c1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.02 10.02 0 0 0 22 12.017C22 6.484 17.522 2 12 2z" />
    </svg>
  );
}

export function DownloadButton({
  size = "lg",
  location = "hero",
}: {
  size?: "sm" | "lg";
  location?: "hero" | "nav" | "footer";
}) {
  const [isMac, setIsMac] = useState<boolean | null>(null);

  useEffect(() => {
    const ua = navigator.userAgent;
    const platform = navigator.platform ?? "";
    setIsMac(
      platform.startsWith("Mac") ||
        ua.includes("Macintosh") ||
        ua.includes("Mac OS X")
    );
  }, []);

  const showMac = isMac !== false;

  const handleClick = () => {
    track("Download", {
      location,
      platform: showMac ? "mac" : "other",
    });
  };

  if (size === "sm") {
    return (
      <a
        href={showMac ? DMG_URL : GITHUB_URL}
        onClick={handleClick}
        className="inline-flex items-center gap-2 rounded-full bg-sj-coral px-5 py-2 font-sans text-sm font-semibold text-white shadow-[0_4px_14px_rgba(180,84,58,0.3)] transition-all duration-200 hover:bg-sj-coral-hover hover:shadow-[0_6px_20px_rgba(180,84,58,0.45)]"
      >
        {showMac ? <AppleIcon className="h-4 w-4" /> : <GitHubIcon className="h-4 w-4" />}
        {showMac ? "Download" : "GitHub"}
      </a>
    );
  }

  return (
    <a
      href={DMG_URL}
      onClick={handleClick}
      className="inline-flex items-center gap-2.5 rounded-full bg-sj-coral px-7 py-3.5 font-sans text-base font-semibold text-white shadow-[0_4px_14px_rgba(180,84,58,0.38)] ring-1 ring-white/20 transition-all duration-200 hover:bg-sj-coral-hover hover:shadow-[0_6px_20px_rgba(180,84,58,0.52)]"
    >
      <AppleIcon className="h-5 w-5" />
      Download for Mac
    </a>
  );
}
