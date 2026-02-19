import type { Metadata } from "next";
import { Playfair_Display, Nunito } from "next/font/google";
import { ThemeProvider } from "next-themes";
import "./globals.css";

const playfair = Playfair_Display({
  subsets: ["latin"],
  variable: "--font-playfair",
  display: "swap",
  weight: ["400", "600", "700", "800"],
});

const nunito = Nunito({
  subsets: ["latin"],
  variable: "--font-nunito",
  display: "swap",
  weight: ["400", "500", "600", "700"],
});

export const metadata: Metadata = {
  metadataBase: new URL("https://storyjuicer.vercel.app"),
  title: "StoryJuicer — AI-Powered Illustrated Children's Storybooks",
  description:
    "Type a story idea, pick a style, and get a fully illustrated children's book with text, cover art, and 300 DPI print-ready PDF export — all on your device.",
  openGraph: {
    title: "StoryJuicer — AI-Powered Illustrated Storybooks",
    description:
      "Type a story idea, pick a style, and get a fully illustrated children's book — all on your Mac. Free to use, no account required.",
    images: [{ url: "/og-image.png", width: 1200, height: 630, alt: "StoryJuicer — AI-powered illustrated children's storybooks" }],
    type: "website",
    siteName: "StoryJuicer",
  },
  twitter: {
    card: "summary_large_image",
    title: "StoryJuicer — AI-Powered Illustrated Storybooks",
    description:
      "Type a story idea, pick a style, and get a fully illustrated children's book — all on your Mac. Free to use, no account required.",
    images: [{ url: "/og-image.png", alt: "StoryJuicer — AI-powered illustrated children's storybooks" }],
  },
  icons: {
    icon: [
      { url: "/favicon.ico", sizes: "48x48" },
      { url: "/icon-192.png", sizes: "192x192", type: "image/png" },
      { url: "/icon-512.png", sizes: "512x512", type: "image/png" },
    ],
    apple: "/apple-touch-icon.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      suppressHydrationWarning
      className={`${playfair.variable} ${nunito.variable}`}
    >
      <body>
        <ThemeProvider attribute="class" defaultTheme="light" enableSystem>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
