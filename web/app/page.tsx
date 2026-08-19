"use client";

import { useState } from "react";
import { copy, type Lang } from "./i18n";

function Leaf() {
  return (
    <span className="leaf">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
        <path d="M12 21c0-6 3-10 9-11-1 7-4 11-9 11z" fill="var(--kb-lime)" />
        <path d="M12 21C8 17 6 12 7 4c5 2 6 8 5 17z" fill="var(--kb-limeDeep)" />
      </svg>
    </span>
  );
}

export default function Home() {
  const [lang, setLang] = useState<Lang>("th");
  const [joined, setJoined] = useState(false);
  const [email, setEmail] = useState("");
  const t = copy[lang];

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    try {
      await fetch("/api/waitlist", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email, lang }),
      });
    } catch {
      /* best-effort */
    }
    setJoined(true);
  }

  return (
    <>
      <nav className="nav">
        <div className="wrap nav-inner">
          <div className="brand">
            <Leaf /> KnowBody
          </div>
          <div className="nav-links">
            <a href="#features">{t.nav.features}</a>
            <a href="#pet">{t.nav.pet}</a>
            <a href="#pricing">{t.nav.pricing}</a>
            <button className="lang" onClick={() => setLang(lang === "th" ? "en" : "th")}>
              {lang === "th" ? "EN" : "ไทย"}
            </button>
            <a href="#waitlist" className="btn btn-ink">
              {t.nav.waitlist}
            </a>
          </div>
        </div>
      </nav>

      <header className="hero">
        <div className="blob" />
        <div className="wrap">
          <span className="tagline">{t.tagline}</span>
          <h1>{t.heroTitle}</h1>
          <p>{t.heroSub}</p>
          <div className="hero-cta">
            <a href="#waitlist" className="btn btn-ink">
              {t.ctaPrimary}
            </a>
            <a href="#features" className="btn btn-ghost">
              {t.ctaSecondary}
            </a>
          </div>
        </div>
      </header>

      <section id="features" className="wrap">
        <h2>{t.featuresTitle}</h2>
        <div className="grid">
          {t.features.map((f) => (
            <div className="card" key={f.t}>
              <h3>{f.t}</h3>
              <p>{f.d}</p>
            </div>
          ))}
        </div>
      </section>

      <section id="pricing" className="wrap">
        <h2>{t.pricingTitle}</h2>
        <div className="plans">
          {t.plans.map((p) => (
            <div className={`plan ${p.highlight ? "hl" : ""}`} key={p.name}>
              <div className="name">{p.name}</div>
              <div className="price">
                ฿{p.price}
                <small>{p.per}</small>
              </div>
              <ul>
                {p.feats.map((f) => (
                  <li key={f}>{f}</li>
                ))}
              </ul>
              <a href="#waitlist" className={`btn ${p.highlight ? "btn-lime" : "btn-ink"}`}>
                {p.cta}
              </a>
            </div>
          ))}
        </div>
      </section>

      <section id="waitlist" className="wrap">
        <div className="waitlist">
          <h2 style={{ marginBottom: 8 }}>{t.waitlistTitle}</h2>
          <p style={{ color: "rgba(18,18,18,.65)" }}>{t.waitlistSub}</p>
          {joined ? (
            <p style={{ marginTop: 22, fontWeight: 600 }}>{t.joined}</p>
          ) : (
            <form onSubmit={submit}>
              <input
                type="email"
                required
                placeholder={t.emailPlaceholder}
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
              <button type="submit" className="btn btn-ink">
                {t.join}
              </button>
            </form>
          )}
        </div>
      </section>

      <footer>
        <div className="wrap">
          KnowBody · {t.footer} · © 2026
        </div>
      </footer>
    </>
  );
}
