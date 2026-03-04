import type { Metadata } from "next";
import { DM_Sans } from "next/font/google";
import { Toaster } from "sonner";
import { Providers } from "@/components/providers";
import "./globals.css";

const dmSans = DM_Sans({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
  variable: "--font-sans",
});

export const metadata: Metadata = {
  title: "Agent Flo — Delegate Tasks. Close Deals.",
  description:
    "The marketplace for real estate agents to outsource photography, showings, staging, open houses, and inspections to vetted licensed professionals.",
  openGraph: {
    title: "Agent Flo — Delegate Tasks. Close Deals.",
    description:
      "The marketplace for real estate agents to outsource photography, showings, staging, open houses, and inspections to vetted licensed professionals.",
    url: "https://agentflo.app",
    siteName: "Agent Flo",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${dmSans.variable} font-sans antialiased`}>
        <Providers>
          {children}
        </Providers>
        <Toaster position="top-right" richColors />
      </body>
    </html>
  );
}
