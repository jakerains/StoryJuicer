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
  title: "StoryJuicer — AI-Powered Illustrated Children's Storybooks",
  description:
    "Type a story idea, pick a style, and get a fully illustrated children's book with text, cover art, and 300 DPI print-ready PDF export — all on your device.",
  openGraph: {
    title: "StoryJuicer",
    description:
      "AI-powered illustrated children's storybooks — on your device.",
    images: [{ url: "/og-image.png", width: 1200, height: 630 }],
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "StoryJuicer",
    description:
      "AI-powered illustrated children's storybooks — on your device.",
    images: ["/og-image.png"],
  },
  icons: { icon: "/favicon.ico", apple: "/app-icon.png" },
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
