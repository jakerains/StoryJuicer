"use client";

import { useState, useEffect } from "react";

const TEXT_MODELS = ["gpt-5-mini", "GPT-5.2"];
const IMAGE_MODELS = ["gpt-image-1-mini", "gpt-image-1.5"];
const IMAGE_QUALITIES = ["low", "medium", "high"];

interface PremiumConfig {
  enabled: boolean;
  textModel: string;
  imageModel: string;
  imageQuality: string;
  imageModelPlus: string;
  imageQualityPlus: string;
}

export default function PremiumAdminPage() {
  const [secret, setSecret] = useState("");
  const [authenticated, setAuthenticated] = useState(false);
  const [config, setConfig] = useState<PremiumConfig | null>(null);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch("/api/premium/config")
      .then((r) => r.json())
      .then((data) => {
        setConfig(data);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  const handleAuth = (e: React.FormEvent) => {
    e.preventDefault();
    if (secret.trim()) setAuthenticated(true);
  };

  const handleSave = async () => {
    if (!config) return;
    setSaving(true);
    setMessage("");

    try {
      const resp = await fetch("/api/premium/config", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${secret}`,
        },
        body: JSON.stringify(config),
      });

      const data = await resp.json();
      if (resp.ok) {
        setMessage("Config saved successfully.");
        if (data.config) setConfig(data.config);
      } else {
        setMessage(`Error: ${data.error}`);
      }
    } catch {
      setMessage("Failed to save config.");
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div style={styles.container}>
        <p style={styles.meta}>Loading...</p>
      </div>
    );
  }

  if (!authenticated) {
    return (
      <div style={styles.container}>
        <div style={styles.card}>
          <h1 style={styles.title}>StoryFox Premium Admin</h1>
          <p style={styles.meta}>Enter the admin secret to continue.</p>
          <form onSubmit={handleAuth} style={styles.form}>
            <input
              type="password"
              value={secret}
              onChange={(e) => setSecret(e.target.value)}
              placeholder="Admin secret"
              style={styles.input}
            />
            <button type="submit" style={styles.button}>
              Authenticate
            </button>
          </form>
        </div>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <h1 style={styles.title}>StoryFox Premium Admin</h1>
        <p style={styles.meta}>
          Configure which OpenAI models the premium proxy uses.
        </p>

        {config && (
          <>
            {/* Kill switch status */}
            <div style={styles.statusBanner}>
              <span
                style={{
                  display: "inline-block",
                  width: 8,
                  height: 8,
                  borderRadius: "50%",
                  backgroundColor: config.enabled ? "#27ae60" : "#e74c3c",
                  marginRight: 8,
                }}
              />
              Premium is{" "}
              <strong>{config.enabled ? "enabled" : "disabled"}</strong>
              {!config.enabled && (
                <span style={{ color: "#999", marginLeft: 8 }}>
                  (Set PREMIUM_ENABLED=true in Vercel env to enable)
                </span>
              )}
            </div>

            <div style={styles.sections}>
              <Section label="Text Model (both tiers)">
                {TEXT_MODELS.map((m) => (
                  <RadioOption
                    key={m}
                    label={m}
                    checked={config.textModel === m}
                    onChange={() => setConfig({ ...config, textModel: m })}
                  />
                ))}
              </Section>

              <div style={styles.tierDivider}>
                <span style={styles.tierLabel}>Premium Tier</span>
              </div>

              <Section label="Image Model">
                {IMAGE_MODELS.map((m) => (
                  <RadioOption
                    key={m}
                    label={m}
                    checked={config.imageModel === m}
                    onChange={() => setConfig({ ...config, imageModel: m })}
                  />
                ))}
              </Section>

              <Section label="Image Quality">
                {IMAGE_QUALITIES.map((q) => (
                  <RadioOption
                    key={q}
                    label={q}
                    checked={config.imageQuality === q}
                    onChange={() => setConfig({ ...config, imageQuality: q })}
                  />
                ))}
              </Section>

              <div style={styles.tierDivider}>
                <span style={styles.tierLabel}>Premium Plus Tier</span>
              </div>

              <Section label="Image Model (Plus)">
                {IMAGE_MODELS.map((m) => (
                  <RadioOption
                    key={m}
                    label={m}
                    checked={config.imageModelPlus === m}
                    onChange={() =>
                      setConfig({ ...config, imageModelPlus: m })
                    }
                  />
                ))}
              </Section>

              <Section label="Image Quality (Plus)">
                {IMAGE_QUALITIES.map((q) => (
                  <RadioOption
                    key={q}
                    label={q}
                    checked={config.imageQualityPlus === q}
                    onChange={() =>
                      setConfig({ ...config, imageQualityPlus: q })
                    }
                  />
                ))}
              </Section>

              <button
                onClick={handleSave}
                disabled={saving}
                style={{
                  ...styles.button,
                  opacity: saving ? 0.6 : 1,
                }}
              >
                {saving ? "Saving..." : "Save Configuration"}
              </button>

              {message && (
                <p
                  style={{
                    ...styles.meta,
                    color: message.startsWith("Error") ? "#e74c3c" : "#27ae60",
                  }}
                >
                  {message}
                </p>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function Section({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div style={styles.section}>
      <h2 style={styles.sectionTitle}>{label}</h2>
      <div style={styles.radioGroup}>{children}</div>
    </div>
  );
}

function RadioOption({
  label,
  checked,
  onChange,
}: {
  label: string;
  checked: boolean;
  onChange: () => void;
}) {
  return (
    <label style={styles.radioLabel}>
      <input
        type="radio"
        checked={checked}
        onChange={onChange}
        style={styles.radio}
      />
      <span>{label}</span>
    </label>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    minHeight: "100vh",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    background: "#1a1a2e",
    padding: "2rem",
    fontFamily: "system-ui, -apple-system, sans-serif",
  },
  card: {
    background: "#16213e",
    borderRadius: "16px",
    padding: "2.5rem",
    maxWidth: "520px",
    width: "100%",
    border: "1px solid rgba(255,255,255,0.08)",
  },
  title: {
    color: "#f5f5f5",
    fontSize: "1.5rem",
    fontWeight: 700,
    margin: "0 0 0.5rem",
  },
  meta: {
    color: "#999",
    fontSize: "0.875rem",
    margin: "0 0 1.5rem",
  },
  form: {
    display: "flex",
    gap: "0.75rem",
  },
  input: {
    flex: 1,
    padding: "0.625rem 0.875rem",
    borderRadius: "8px",
    border: "1px solid rgba(255,255,255,0.15)",
    background: "rgba(255,255,255,0.05)",
    color: "#f5f5f5",
    fontSize: "0.875rem",
    outline: "none",
  },
  button: {
    padding: "0.625rem 1.25rem",
    borderRadius: "8px",
    border: "none",
    background: "linear-gradient(135deg, #B4543A, #D98A73)",
    color: "#fff",
    fontSize: "0.875rem",
    fontWeight: 600,
    cursor: "pointer",
  },
  sections: {
    display: "flex",
    flexDirection: "column" as const,
    gap: "1.5rem",
  },
  section: {
    display: "flex",
    flexDirection: "column" as const,
    gap: "0.5rem",
  },
  sectionTitle: {
    color: "#ccc",
    fontSize: "0.8125rem",
    fontWeight: 600,
    textTransform: "uppercase" as const,
    letterSpacing: "0.05em",
    margin: 0,
  },
  radioGroup: {
    display: "flex",
    gap: "1rem",
  },
  radioLabel: {
    display: "flex",
    alignItems: "center",
    gap: "0.375rem",
    color: "#e0e0e0",
    fontSize: "0.875rem",
    cursor: "pointer",
  },
  radio: {
    accentColor: "#D98A73",
  },
  statusBanner: {
    display: "flex",
    alignItems: "center",
    padding: "0.625rem 1rem",
    borderRadius: "8px",
    background: "rgba(255,255,255,0.04)",
    border: "1px solid rgba(255,255,255,0.08)",
    color: "#e0e0e0",
    fontSize: "0.875rem",
    marginBottom: "1.5rem",
  },
  tierDivider: {
    borderTop: "1px solid rgba(255,255,255,0.1)",
    paddingTop: "0.75rem",
    marginTop: "0.25rem",
  },
  tierLabel: {
    color: "#D98A73",
    fontSize: "0.75rem",
    fontWeight: 700,
    textTransform: "uppercase" as const,
    letterSpacing: "0.08em",
  },
};
