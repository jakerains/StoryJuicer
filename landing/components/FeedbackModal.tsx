"use client";

import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";

const CATEGORIES = [
  { value: "suggestion", label: "Suggestion" },
  { value: "bug", label: "Bug Report" },
  { value: "complaint", label: "Complaint" },
  { value: "other", label: "Other" },
] as const;

type Category = (typeof CATEGORIES)[number]["value"];
type FormState = "idle" | "submitting" | "success" | "error";

interface FeedbackModalProps {
  open: boolean;
  onClose: () => void;
}

export function FeedbackModal({ open, onClose }: FeedbackModalProps) {
  const [category, setCategory] = useState<Category>("suggestion");
  const [message, setMessage] = useState("");
  const [email, setEmail] = useState("");
  const [formState, setFormState] = useState<FormState>("idle");
  const [errorMsg, setErrorMsg] = useState("");

  // Lock body scroll when modal is open
  useEffect(() => {
    if (open) {
      document.body.style.overflow = "hidden";
    } else {
      document.body.style.overflow = "";
    }
    return () => {
      document.body.style.overflow = "";
    };
  }, [open]);

  // Reset form when modal closes
  useEffect(() => {
    if (!open) {
      // Small delay so the closing animation finishes before resetting
      const t = setTimeout(() => {
        setFormState("idle");
        setMessage("");
        setEmail("");
        setCategory("suggestion");
        setErrorMsg("");
      }, 300);
      return () => clearTimeout(t);
    }
  }, [open]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();

    if (!message.trim()) return;

    setFormState("submitting");
    setErrorMsg("");

    try {
      const res = await fetch("/api/feedback", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          category,
          message: message.trim(),
          email: email.trim() || undefined,
        }),
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || "Submission failed");
      }

      setFormState("success");
      setMessage("");
      setEmail("");
      setCategory("suggestion");
    } catch (err) {
      setErrorMsg(
        err instanceof Error ? err.message : "Something went wrong."
      );
      setFormState("error");
    }
  }

  return (
    <AnimatePresence>
      {open && (
        <>
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            onClick={onClose}
            onKeyDown={(e) => e.key === "Escape" && onClose()}
            className="fixed inset-0 z-50 bg-black/40 backdrop-blur-sm"
          />

          {/* Modal panel */}
          <motion.div
            initial={{ opacity: 0, scale: 0.95, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 20 }}
            transition={{ duration: 0.25, ease: "easeOut" }}
            className="fixed inset-0 z-50 flex items-center justify-center p-4"
          >
            <div
              className="relative w-full max-w-lg max-h-[90vh] overflow-y-auto rounded-2xl border border-sj-border/30 bg-[var(--sj-bg-top)] shadow-2xl"
              onClick={(e) => e.stopPropagation()}
            >
              {/* Close button */}
              <button
                onClick={onClose}
                className="absolute right-4 top-4 flex h-8 w-8 items-center justify-center rounded-full text-sj-muted transition-colors hover:bg-[var(--sj-glass-soft)] hover:text-sj-text"
                aria-label="Close"
              >
                <svg
                  className="h-5 w-5"
                  fill="none"
                  viewBox="0 0 24 24"
                  strokeWidth={2}
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>

              {/* Header */}
              <div className="px-6 pt-7 pb-1 sm:px-8 sm:pt-8">
                <h3 className="mb-2 font-serif text-xl font-semibold text-sj-text sm:text-2xl">
                  Share Your Feedback
                </h3>
                <p className="pr-8 text-sm leading-relaxed text-sj-secondary">
                  Whether it&apos;s a feature idea, a bug you found, or just
                  something on your mind — we&apos;d love to hear from you.
                </p>
              </div>

              {/* Divider */}
              <div className="mx-6 my-4 h-px bg-sj-border/20 sm:mx-8" />

              {/* Form / Success */}
              <div className="px-6 pb-7 sm:px-8 sm:pb-8">
                {formState === "success" ? (
                  <div className="flex flex-col items-center gap-3 py-6 text-center">
                    <div className="flex h-14 w-14 items-center justify-center rounded-full bg-[var(--sj-mint)]/15">
                      <svg
                        className="h-7 w-7 text-sj-mint"
                        fill="none"
                        viewBox="0 0 24 24"
                        strokeWidth={2}
                        stroke="currentColor"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          d="M4.5 12.75l6 6 9-13.5"
                        />
                      </svg>
                    </div>
                    <h4 className="font-serif text-lg font-semibold text-sj-text">
                      Thank you!
                    </h4>
                    <p className="max-w-sm text-sm text-sj-secondary">
                      Your feedback has been received. We read every submission
                      and appreciate you taking the time.
                    </p>
                    <div className="mt-2 flex gap-3">
                      <button
                        onClick={() => setFormState("idle")}
                        className="text-sm font-medium text-sj-coral underline decoration-sj-coral/30 underline-offset-2 transition-colors hover:decoration-sj-coral"
                      >
                        Send another
                      </button>
                      <button
                        onClick={onClose}
                        className="text-sm font-medium text-sj-muted underline decoration-sj-muted/30 underline-offset-2 transition-colors hover:decoration-sj-muted"
                      >
                        Close
                      </button>
                    </div>
                  </div>
                ) : (
                  <form onSubmit={handleSubmit} className="space-y-5">
                    {/* Category pills */}
                    <div>
                      <label className="mb-2 block text-xs font-semibold uppercase tracking-wider text-sj-muted">
                        Category
                      </label>
                      <div className="flex flex-wrap gap-2">
                        {CATEGORIES.map((cat) => (
                          <button
                            key={cat.value}
                            type="button"
                            onClick={() => setCategory(cat.value)}
                            className={`rounded-full px-4 py-1.5 text-sm font-medium transition-all ${
                              category === cat.value
                                ? "bg-sj-coral text-white shadow-sm"
                                : "bg-[var(--sj-glass-soft)] text-sj-secondary hover:bg-[var(--sj-glass-weak)] hover:text-sj-text"
                            }`}
                          >
                            {cat.label}
                          </button>
                        ))}
                      </div>
                    </div>

                    {/* Message textarea */}
                    <div>
                      <label
                        htmlFor="feedback-message"
                        className="mb-2 block text-xs font-semibold uppercase tracking-wider text-sj-muted"
                      >
                        Message
                      </label>
                      <textarea
                        id="feedback-message"
                        value={message}
                        onChange={(e) => setMessage(e.target.value)}
                        placeholder="Tell us what's on your mind..."
                        maxLength={2000}
                        required
                        rows={4}
                        className="w-full resize-none rounded-xl border border-sj-border/30 bg-[var(--sj-glass-weak)] px-4 py-3 text-sm text-sj-text placeholder:text-sj-muted/60 focus:border-sj-coral/50 focus:outline-none focus:ring-2 focus:ring-sj-coral/20 transition-colors"
                      />
                      <p className="mt-1 text-right text-xs text-sj-muted/60">
                        {message.length}/2000
                      </p>
                    </div>

                    {/* Email input */}
                    <div>
                      <label
                        htmlFor="feedback-email"
                        className="mb-2 block text-xs font-semibold uppercase tracking-wider text-sj-muted"
                      >
                        Email
                      </label>
                      <input
                        id="feedback-email"
                        type="email"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        placeholder="you@example.com"
                        className="w-full rounded-xl border border-sj-border/30 bg-[var(--sj-glass-weak)] px-4 py-2.5 text-sm text-sj-text placeholder:text-sj-muted/60 focus:border-sj-coral/50 focus:outline-none focus:ring-2 focus:ring-sj-coral/20 transition-colors"
                      />
                      <p className="mt-1 text-xs text-sj-muted/60">
                        Optional — only if you&apos;d like a response
                      </p>
                    </div>

                    {/* Error message */}
                    {formState === "error" && errorMsg && (
                      <p className="rounded-lg bg-red-500/10 px-4 py-2 text-sm text-red-600 dark:text-red-400">
                        {errorMsg}
                      </p>
                    )}

                    {/* Submit button */}
                    <button
                      type="submit"
                      disabled={
                        formState === "submitting" ||
                        message.trim().length === 0
                      }
                      className="inline-flex items-center gap-2 rounded-full bg-sj-coral px-6 py-2.5 text-sm font-semibold text-white shadow-sm transition-all hover:bg-sj-coral-hover disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {formState === "submitting" ? (
                        <>
                          <svg
                            className="h-4 w-4 animate-spin"
                            viewBox="0 0 24 24"
                            fill="none"
                          >
                            <circle
                              className="opacity-25"
                              cx="12"
                              cy="12"
                              r="10"
                              stroke="currentColor"
                              strokeWidth="4"
                            />
                            <path
                              className="opacity-75"
                              fill="currentColor"
                              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
                            />
                          </svg>
                          Sending...
                        </>
                      ) : (
                        "Send Feedback"
                      )}
                    </button>
                  </form>
                )}
              </div>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
