import { cn } from "@/lib/utils";

interface GlassCardProps {
  children: React.ReactNode;
  className?: string;
  hover?: boolean;
}

export function GlassCard({ children, className, hover = false }: GlassCardProps) {
  return (
    <div
      className={cn(
        "glass-border relative rounded-[18px] backdrop-blur-xl",
        "bg-[var(--sj-glass-soft)]/10",
        "shadow-[0_6px_12px_rgba(0,0,0,0.08)]",
        hover && "transition-all duration-200 hover:-translate-y-1 hover:shadow-[0_10px_24px_rgba(0,0,0,0.12)]",
        className
      )}
    >
      {children}
    </div>
  );
}
