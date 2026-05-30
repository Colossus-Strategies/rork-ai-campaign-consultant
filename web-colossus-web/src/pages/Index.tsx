import { useState, type FormEvent } from "react";
import {
  DollarSign,
  Users,
  MessageSquareQuote,
  Map,
  ShieldCheck,
  Newspaper,
  MessagesSquare,
  ArrowRight,
  Apple,
  Crosshair,
  Check,
  Clock,
  Menu,
  X,
} from "lucide-react";
import { useReveal } from "@/hooks/useReveal";
import { toast } from "sonner";

const APP_STORE_URL = "#"; // TODO: replace with real App Store link
const CONTACT_EMAIL = "team@colossus.app"; // TODO: replace with real email

type ModuleItem = {
  icon: typeof DollarSign;
  title: string;
  tagline: string;
  blurb: string;
  color: string;
};

const MODULES: ModuleItem[] = [
  {
    icon: DollarSign,
    title: "Fundraising Coach",
    tagline: "Money is oxygen. Train the discipline.",
    blurb: "Build a real call-time habit, work your donor list, and ask without flinching.",
    color: "44 53% 54%",
  },
  {
    icon: Users,
    title: "Voter Contact",
    tagline: "Doors, phones, texts — the votes are out there.",
    blurb: "Build a contact universe, hit your daily IDs, and convert leaners into hard yeses.",
    color: "217 73% 67%",
  },
  {
    icon: MessageSquareQuote,
    title: "Messaging",
    tagline: "What you stand for. In one sentence.",
    blurb: "Sharpen your core message and stay on it under pressure — mail, video, and the stump.",
    color: "265 100% 76%",
  },
  {
    icon: Map,
    title: "Field Operations",
    tagline: "Volunteers, turf, GOTV — the ground game.",
    blurb: "Recruit a volunteer corps, cut turf intelligently, and run a GOTV that actually pulls voters.",
    color: "165 50% 54%",
  },
  {
    icon: ShieldCheck,
    title: "Compliance Guardrails",
    tagline: "Don't lose the race in the filing cabinet.",
    blurb: "Stay on the right side of contribution limits, coordination rules, and reporting deadlines.",
    color: "44 53% 54%",
  },
  {
    icon: Newspaper,
    title: "Earned Media",
    tagline: "The press is a megaphone. Make it ring.",
    blurb: "Pitch reporters, run a press conference, and turn a moment into momentum.",
    color: "20 100% 67%",
  },
];

type ServiceItem = {
  eyebrow: string;
  title: string;
  tagline: string;
  body: string;
  bullets: string[];
  color: string;
};

const SERVICES: ServiceItem[] = [
  {
    eyebrow: "Fundraising",
    title: "Colossus Fundraising Pro",
    tagline: "Raise the money you need to win.",
    body: "Unlimited access to fundraising data, donor intelligence, and a dedicated Customer Success Manager who keeps your campaign on track.",
    bullets: [
      "Unlimited fundraising data access",
      "Dedicated Customer Success Manager",
      "Donor targeting & call-time planning",
      "Finance strategy recommendations",
    ],
    color: "150 44% 49%",
  },
  {
    eyebrow: "Strategy",
    title: "Colossus Deep Strategy",
    tagline: "Targeted research and strategic firepower.",
    body: "Advanced research, analysis, and live support from top consultants nationwide — opposition research, district analysis, and rapid response.",
    bullets: [
      "Opposition & targeted research",
      "District and voter analysis",
      "Strategic messaging support",
      "Live consultant & rapid response",
    ],
    color: "5 64% 53%",
  },
];

function Nav() {
  const [open, setOpen] = useState<boolean>(false);
  const links: { label: string; href: string }[] = [
    { label: "Consultant", href: "#consultant" },
    { label: "Modules", href: "#modules" },
    { label: "District Data", href: "#district" },
    { label: "Services", href: "#services" },
  ];

  return (
    <header className="fixed top-0 inset-x-0 z-50 border-b border-[hsl(var(--gold)/0.12)] bg-[hsl(var(--ink)/0.7)] backdrop-blur-xl">
      <div className="container flex items-center justify-between h-16">
        <a href="#top" className="flex items-center gap-2.5">
          <img src="/colossus-logo.png" alt="Colossus" className="h-8 w-8 rounded-md object-contain" />
          <span className="font-serif font-bold text-lg tracking-tight">Colossus</span>
        </a>

        <nav className="hidden md:flex items-center gap-8">
          {links.map((l) => (
            <a
              key={l.href}
              href={l.href}
              className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
            >
              {l.label}
            </a>
          ))}
        </nav>

        <a
          href={APP_STORE_URL}
          className="hidden md:inline-flex items-center gap-2 rounded-full bg-[hsl(var(--gold))] px-4 py-2 text-sm font-bold text-[hsl(var(--ink))] hover:bg-[hsl(var(--gold-light))] transition-colors"
        >
          <Apple className="h-4 w-4" /> Download
        </a>

        <button
          className="md:hidden p-2 text-foreground"
          onClick={() => setOpen((v) => !v)}
          aria-label="Toggle menu"
        >
          {open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
        </button>
      </div>

      {open && (
        <div className="md:hidden border-t border-[hsl(var(--gold)/0.12)] bg-[hsl(var(--ink)/0.95)]">
          <div className="container py-4 flex flex-col gap-3">
            {links.map((l) => (
              <a
                key={l.href}
                href={l.href}
                onClick={() => setOpen(false)}
                className="text-sm font-medium text-muted-foreground hover:text-foreground py-1"
              >
                {l.label}
              </a>
            ))}
            <a
              href={APP_STORE_URL}
              className="inline-flex items-center justify-center gap-2 rounded-full bg-[hsl(var(--gold))] px-4 py-2.5 text-sm font-bold text-[hsl(var(--ink))]"
            >
              <Apple className="h-4 w-4" /> Download on the App Store
            </a>
          </div>
        </div>
      )}
    </header>
  );
}

function Hero() {
  return (
    <section id="top" className="relative min-h-[100svh] flex items-center overflow-hidden">
      <img
        src="/hero-bg.png"
        alt=""
        aria-hidden
        className="absolute inset-0 h-full w-full object-cover opacity-80"
      />
      <div className="absolute inset-0 bg-gradient-to-b from-[hsl(var(--ink)/0.55)] via-[hsl(var(--ink)/0.7)] to-[hsl(var(--background))]" />

      <div className="container relative z-10 pt-28 pb-20">
        <div className="max-w-3xl">
          <div className="animate-fade-up inline-flex items-center gap-2 rounded-full border border-[hsl(var(--gold)/0.35)] bg-[hsl(var(--ink)/0.5)] px-4 py-1.5 mb-7 backdrop-blur">
            <span className="h-2 w-2 rounded-full bg-[hsl(var(--gold))] animate-pulse-dot" />
            <span className="text-xs font-bold uppercase tracking-[0.18em] text-[hsl(var(--gold-light))]">
              Your AI Campaign Consultant
            </span>
          </div>

          <h1
            className="animate-fade-up font-serif font-black leading-[0.95] tracking-tight text-foreground"
            style={{ fontSize: "clamp(3rem, 9vw, 6.5rem)", animationDelay: "0.05s" }}
          >
            Built For
            <br />
            <span className="gold-text">Your Race.</span>
          </h1>

          <p
            className="animate-fade-up mt-7 max-w-xl text-lg text-muted-foreground leading-relaxed"
            style={{ animationDelay: "0.15s" }}
          >
            Every answer, checklist, and drill is tailored to your race level, jurisdiction, and
            timeline. A war-room consultant in your pocket — on call 24/7.
          </p>

          <div
            className="animate-fade-up mt-9 flex flex-col sm:flex-row gap-4"
            style={{ animationDelay: "0.25s" }}
          >
            <a
              href={APP_STORE_URL}
              className="gold-glow inline-flex items-center justify-center gap-2.5 rounded-full bg-[hsl(var(--gold))] px-7 py-3.5 font-bold text-[hsl(var(--ink))] hover:bg-[hsl(var(--gold-light))] transition-colors"
            >
              <Apple className="h-5 w-5" /> Download on the App Store
            </a>
            <a
              href="#consultant"
              className="inline-flex items-center justify-center gap-2 rounded-full border border-[hsl(var(--gold)/0.4)] px-7 py-3.5 font-semibold text-foreground hover:bg-[hsl(var(--surface)/0.6)] transition-colors"
            >
              See how it works <ArrowRight className="h-4 w-4" />
            </a>
          </div>

          <p
            className="animate-fade-up mt-10 text-xs font-bold uppercase tracking-[0.32em] text-[hsl(var(--gold-dim))]"
            style={{ animationDelay: "0.35s" }}
          >
            Educate · Empower · Win
          </p>
        </div>
      </div>
    </section>
  );
}

function Stats() {
  const stats: { value: string; label: string }[] = [
    { value: "6", label: "Strategy modules" },
    { value: "24/7", label: "Race-aware AI coach" },
    { value: "50", label: "States covered" },
    { value: "1:1", label: "Pro consultant support" },
  ];
  return (
    <section className="border-y border-[hsl(var(--gold)/0.12)] bg-[hsl(var(--ink)/0.4)]">
      <div className="container grid grid-cols-2 md:grid-cols-4 gap-8 py-12">
        {stats.map((s) => (
          <div key={s.label} className="reveal text-center">
            <div className="font-serif font-black text-4xl md:text-5xl gold-text">{s.value}</div>
            <div className="mt-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              {s.label}
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

function Consultant() {
  return (
    <section id="consultant" className="container py-24 md:py-32">
      <div className="grid lg:grid-cols-2 gap-14 items-center">
        <div className="reveal">
          <p className="eyebrow">The Consultant</p>
          <h2 className="mt-4 font-serif font-bold text-4xl md:text-5xl leading-tight">
            Ask anything.
            <br />
            Get a <span className="gold-text">real answer.</span>
          </h2>
          <p className="mt-6 text-muted-foreground text-lg leading-relaxed">
            Your race context travels with every question — including a compliance check when you're
            near a finance rule. No generic playbooks. Just sharp, specific guidance for the campaign
            you're actually running.
          </p>
          <ul className="mt-8 space-y-4">
            {[
              "Race-aware answers tuned to your office, district, and timeline",
              "Built-in compliance guardrails on finance questions",
              "From call-time scripts to GOTV plans — all in one chat",
            ].map((line) => (
              <li key={line} className="flex items-start gap-3">
                <span className="mt-1 flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-[hsl(var(--gold)/0.15)]">
                  <Check className="h-3 w-3 text-[hsl(var(--gold))]" strokeWidth={3} />
                </span>
                <span className="text-foreground/90">{line}</span>
              </li>
            ))}
          </ul>
        </div>

        <div className="reveal">
          <ChatMock />
        </div>
      </div>
    </section>
  );
}

function ChatMock() {
  return (
    <div className="glass-card rounded-3xl p-5 md:p-6 max-w-md mx-auto gold-glow">
      <div className="flex items-center gap-3 pb-4 border-b border-[hsl(var(--gold)/0.15)]">
        <div className="flex h-10 w-10 items-center justify-center rounded-full bg-gradient-to-br from-[hsl(var(--gold-light))] to-[hsl(var(--gold))]">
          <MessagesSquare className="h-5 w-5 text-[hsl(var(--ink))]" />
        </div>
        <div>
          <div className="font-serif font-bold">The Consultant</div>
          <div className="flex items-center gap-1.5 text-xs text-[hsl(150_44%_55%)]">
            <span className="h-1.5 w-1.5 rounded-full bg-[hsl(150_44%_55%)] animate-pulse-dot" />
            Online · race-aware
          </div>
        </div>
      </div>

      <div className="space-y-3 pt-5">
        <div className="ml-auto max-w-[80%] rounded-2xl rounded-tr-sm bg-[hsl(216_60%_33%)] px-4 py-2.5 text-sm">
          I'm 6 weeks out and behind on cash. What do I do this week?
        </div>
        <div className="max-w-[88%] rounded-2xl rounded-tl-sm bg-[hsl(var(--surface-2))] px-4 py-3 text-sm leading-relaxed text-foreground/90">
          Two 90-minute call-time blocks a day, four days this week. Start with your top 25 A-list
          prospects and ask at the max. Want me to draft your opening script?
        </div>
        <div className="flex gap-2 pt-1">
          <span className="rounded-full border border-[hsl(var(--gold)/0.3)] px-3 py-1 text-xs text-[hsl(var(--gold-light))]">
            Draft my script
          </span>
          <span className="rounded-full border border-[hsl(var(--gold)/0.3)] px-3 py-1 text-xs text-[hsl(var(--gold-light))]">
            Build my list
          </span>
        </div>
      </div>
    </div>
  );
}

function Modules() {
  return (
    <section id="modules" className="container py-24 md:py-32">
      <div className="reveal text-center max-w-2xl mx-auto">
        <p className="eyebrow">The Six Modules</p>
        <h2 className="mt-4 font-serif font-bold text-4xl md:text-5xl">One playbook. Six fronts.</h2>
        <p className="mt-5 text-muted-foreground text-lg">
          Bite-size training and real exercises for every part of a winning campaign.
        </p>
      </div>

      <div className="mt-14 grid sm:grid-cols-2 lg:grid-cols-3 gap-5">
        {MODULES.map((m, i) => {
          const Icon = m.icon;
          return (
            <div
              key={m.title}
              className="reveal glass-card group rounded-2xl p-6 transition-all duration-300 hover:-translate-y-1 hover:border-[hsl(var(--gold)/0.45)]"
              style={{ transitionDelay: `${i * 40}ms` }}
            >
              <div
                className="flex h-12 w-12 items-center justify-center rounded-xl"
                style={{ backgroundColor: `hsl(${m.color} / 0.15)` }}
              >
                <Icon className="h-6 w-6" style={{ color: `hsl(${m.color})` }} />
              </div>
              <h3 className="mt-5 font-serif font-bold text-xl">{m.title}</h3>
              <p className="mt-1.5 text-sm font-semibold text-[hsl(var(--gold-light))]">{m.tagline}</p>
              <p className="mt-3 text-sm text-muted-foreground leading-relaxed">{m.blurb}</p>
            </div>
          );
        })}
      </div>
    </section>
  );
}

function District() {
  const tags: string[] = ["Voter file", "Turnout", "Walk lists", "Persuasion", "GOTV", "Custom"];
  return (
    <section id="district" className="container py-24 md:py-32">
      <div className="reveal glass-card relative overflow-hidden rounded-3xl p-8 md:p-14">
        <div className="absolute -right-24 -top-24 h-64 w-64 rounded-full bg-[hsl(var(--gold)/0.12)] blur-3xl" />
        <div className="relative grid lg:grid-cols-2 gap-10 items-center">
          <div>
            <div className="inline-flex items-center gap-2 rounded-full bg-[hsl(150_44%_49%/0.14)] px-3 py-1 mb-5">
              <span className="h-1.5 w-1.5 rounded-full bg-[hsl(150_44%_55%)]" />
              <span className="text-xs font-bold uppercase tracking-wider text-[hsl(150_44%_60%)]">
                Included in app
              </span>
            </div>
            <h2 className="font-serif font-bold text-4xl md:text-5xl leading-tight">
              Know your district <span className="gold-text">inside out.</span>
            </h2>
            <p className="mt-5 text-muted-foreground text-lg leading-relaxed">
              Request a custom data pull for your race — voter file, turnout history, persuasion
              universes, and precinct-level analytics, delivered by the Colossus team.
            </p>
            <div className="mt-7 flex flex-wrap gap-2.5">
              {tags.map((t) => (
                <span
                  key={t}
                  className="rounded-full border border-[hsl(var(--gold)/0.25)] bg-[hsl(var(--input))] px-3.5 py-1.5 text-sm font-semibold text-foreground/80"
                >
                  {t}
                </span>
              ))}
            </div>
          </div>

          <div className="flex justify-center">
            <div className="relative flex h-48 w-48 items-center justify-center rounded-3xl bg-[hsl(var(--input))] border border-[hsl(var(--gold)/0.2)]">
              <Map className="h-20 w-20 text-[hsl(var(--gold))]" strokeWidth={1.2} />
              <div className="absolute inset-0 rounded-3xl bg-[hsl(var(--gold)/0.06)] animate-pulse-dot" />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function Services() {
  return (
    <section id="services" className="container py-24 md:py-32">
      <div className="reveal text-center max-w-2xl mx-auto">
        <p className="eyebrow">Pro Services</p>
        <h2 className="mt-4 font-serif font-bold text-4xl md:text-5xl">
          When you need more than the toolkit.
        </h2>
        <p className="mt-5 text-muted-foreground text-lg">
          Fundraising firepower and strategic backup, built for campaigns playing to win.
        </p>
      </div>

      <div className="mt-14 grid md:grid-cols-2 gap-6">
        {SERVICES.map((s) => (
          <div key={s.title} className="reveal glass-card rounded-3xl p-8">
            <div className="flex items-center gap-4">
              <div
                className="flex h-12 w-12 items-center justify-center rounded-xl"
                style={{ backgroundColor: `hsl(${s.color})` }}
              >
                {s.eyebrow === "Fundraising" ? (
                  <DollarSign className="h-6 w-6 text-[hsl(var(--ink))]" />
                ) : (
                  <Crosshair className="h-6 w-6 text-[hsl(var(--ink))]" />
                )}
              </div>
              <div>
                <p
                  className="text-xs font-bold uppercase tracking-wider"
                  style={{ color: `hsl(${s.color})` }}
                >
                  {s.eyebrow}
                </p>
                <h3 className="font-serif font-bold text-2xl">{s.title}</h3>
              </div>
            </div>
            <p className="mt-5 font-semibold text-[hsl(var(--gold-light))]">{s.tagline}</p>
            <p className="mt-3 text-muted-foreground leading-relaxed">{s.body}</p>
            <ul className="mt-6 space-y-3">
              {s.bullets.map((b) => (
                <li key={b} className="flex items-start gap-3 text-sm text-foreground/90">
                  <Check
                    className="mt-0.5 h-4 w-4 shrink-0"
                    style={{ color: `hsl(${s.color})` }}
                    strokeWidth={3}
                  />
                  {b}
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>

      <p className="reveal mt-8 flex items-center justify-center gap-2 text-sm text-muted-foreground">
        <Clock className="h-4 w-4" /> Pricing shared after review · Typical response: 1 business day.
      </p>
    </section>
  );
}

function Contact() {
  const [submitted, setSubmitted] = useState<boolean>(false);

  function handleSubmit(e: FormEvent<HTMLFormElement>): void {
    e.preventDefault();
    setSubmitted(true);
    toast.success("Request received — we'll be in touch within 1 business day.");
  }

  return (
    <section id="contact" className="container py-24 md:py-32">
      <div className="reveal glass-card mx-auto max-w-2xl rounded-3xl p-8 md:p-12 text-center gold-glow">
        <p className="eyebrow">Get Started</p>
        <h2 className="mt-4 font-serif font-bold text-3xl md:text-4xl">
          Run a smarter campaign.
        </h2>
        <p className="mt-4 text-muted-foreground">
          Download the app, or tell us what your campaign needs and we'll reach out.
        </p>

        {submitted ? (
          <div className="mt-8 rounded-2xl bg-[hsl(150_44%_49%/0.12)] border border-[hsl(150_44%_49%/0.3)] p-6">
            <Check className="mx-auto h-8 w-8 text-[hsl(150_44%_55%)]" strokeWidth={2.5} />
            <p className="mt-3 font-semibold">Thanks — your request is in.</p>
            <p className="mt-1 text-sm text-muted-foreground">
              We typically respond within one business day.
            </p>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="mt-8 space-y-4 text-left">
            <div className="grid sm:grid-cols-2 gap-4">
              <input
                required
                placeholder="Your name"
                className="w-full rounded-xl bg-[hsl(var(--input))] border border-[hsl(var(--gold)/0.2)] px-4 py-3 text-sm outline-none focus:border-[hsl(var(--gold)/0.6)] transition-colors"
              />
              <input
                required
                type="email"
                placeholder="Email"
                className="w-full rounded-xl bg-[hsl(var(--input))] border border-[hsl(var(--gold)/0.2)] px-4 py-3 text-sm outline-none focus:border-[hsl(var(--gold)/0.6)] transition-colors"
              />
            </div>
            <input
              placeholder="Office you're running for (e.g. State House, District 12)"
              className="w-full rounded-xl bg-[hsl(var(--input))] border border-[hsl(var(--gold)/0.2)] px-4 py-3 text-sm outline-none focus:border-[hsl(var(--gold)/0.6)] transition-colors"
            />
            <textarea
              rows={3}
              placeholder="What does your campaign need?"
              className="w-full rounded-xl bg-[hsl(var(--input))] border border-[hsl(var(--gold)/0.2)] px-4 py-3 text-sm outline-none focus:border-[hsl(var(--gold)/0.6)] transition-colors resize-none"
            />
            <button
              type="submit"
              className="w-full rounded-full bg-[hsl(var(--gold))] px-6 py-3.5 font-bold text-[hsl(var(--ink))] hover:bg-[hsl(var(--gold-light))] transition-colors"
            >
              Request a callback
            </button>
          </form>
        )}

        <div className="mt-8 flex flex-col sm:flex-row items-center justify-center gap-4">
          <a
            href={APP_STORE_URL}
            className="inline-flex items-center gap-2 text-sm font-semibold text-[hsl(var(--gold-light))] hover:text-[hsl(var(--gold))]"
          >
            <Apple className="h-4 w-4" /> Download on the App Store
          </a>
          <span className="hidden sm:inline text-muted-foreground">·</span>
          <a
            href={`mailto:${CONTACT_EMAIL}`}
            className="text-sm font-semibold text-muted-foreground hover:text-foreground"
          >
            {CONTACT_EMAIL}
          </a>
        </div>
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="border-t border-[hsl(var(--gold)/0.12)] bg-[hsl(var(--ink)/0.5)]">
      <div className="container py-12">
        <div className="flex flex-col md:flex-row items-center justify-between gap-6">
          <div className="flex items-center gap-2.5">
            <img src="/colossus-logo.png" alt="Colossus" className="h-8 w-8 rounded-md object-contain" />
            <span className="font-serif font-bold text-lg">Colossus</span>
          </div>
          <p className="text-xs font-bold uppercase tracking-[0.3em] text-[hsl(var(--gold-dim))]">
            Educate · Empower · Win
          </p>
          <div className="flex items-center gap-6 text-sm text-muted-foreground">
            <a href="#modules" className="hover:text-foreground">Modules</a>
            <a href="#services" className="hover:text-foreground">Services</a>
            <a href="#contact" className="hover:text-foreground">Contact</a>
          </div>
        </div>
        <p className="mt-8 text-center text-xs text-muted-foreground">
          © {new Date().getFullYear()} Colossus. Your AI Campaign Consultant.
        </p>
      </div>
    </footer>
  );
}

export default function Index() {
  useReveal();
  return (
    <div className="min-h-screen bg-background text-foreground overflow-x-hidden">
      <Nav />
      <main>
        <Hero />
        <Stats />
        <Consultant />
        <Modules />
        <District />
        <Services />
        <Contact />
      </main>
      <Footer />
    </div>
  );
}
