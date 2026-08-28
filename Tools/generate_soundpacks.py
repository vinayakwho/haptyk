#!/usr/bin/env python3
import os
import math
import wave
import struct
import random
import json

SAMPLE_RATE = 48000

SWITCH_DEFINITIONS = [
    {
        "id": "alpaca",
        "name": "Alpaca",
        "category": "Linear",
        "actuation_force": "62g bottom-out",
        "travel": "4.0mm",
        "description": "Buttery smooth linear switch with JWK polycarbonate housing and nylon bottom. Soft, gentle bottom-out sound with smooth acoustic glide.",
        "color": "#83A99F",
        "tone_base": 580.0,
        "clackiness": 0.65,
        "thockiness": 0.70,
        "click_intensity": 0.0,
        "spring_ping": 0.08,
        "damping": 38.0,
    },
    {
        "id": "blue_alps",
        "name": "Blue Alps",
        "category": "Clicky",
        "actuation_force": "70g actuation",
        "travel": "3.5mm",
        "description": "Legendary vintage Alps SKCM Blue switch known for its crisp, resonant clickleaf mechanism and deep metallic acoustic resonance.",
        "color": "#3B82F6",
        "tone_base": 820.0,
        "clackiness": 0.90,
        "thockiness": 0.50,
        "click_intensity": 0.95,
        "spring_ping": 0.40,
        "damping": 28.0,
    },
    {
        "id": "buckling_spring",
        "name": "Buckling Spring",
        "category": "IBM Model M",
        "actuation_force": "65g-70g",
        "travel": "3.7mm",
        "description": "The quintessential vintage IBM Model M acoustic signature. Massive steel plate impact, buckling spring crunch, and long ringing metallic ping.",
        "color": "#E5E7EB",
        "tone_base": 550.0,
        "clackiness": 0.95,
        "thockiness": 0.85,
        "click_intensity": 0.90,
        "spring_ping": 0.80,
        "damping": 20.0,
    },
    {
        "id": "cherry_mx_black",
        "name": "Cherry MX Black PBT",
        "category": "Linear",
        "actuation_force": "60g actuation / 80g bottom",
        "travel": "4.0mm",
        "description": "Heavy, solid vintage linear switch paired with thick PBT keycaps. Deep, muted low-frequency impact with substantial weight.",
        "color": "#1F2937",
        "tone_base": 480.0,
        "clackiness": 0.65,
        "thockiness": 0.85,
        "click_intensity": 0.0,
        "spring_ping": 0.10,
        "damping": 42.0,
    },
    {
        "id": "cherry_mx_blue",
        "name": "Cherry MX Blue PBT",
        "category": "Clicky",
        "actuation_force": "50g actuation / 60g click",
        "travel": "4.0mm",
        "description": "Classic click-jacket mechanical switch. Sharp, snappy, high-pitched mechanical click followed by crisp bottom-out on PBT keycaps.",
        "color": "#2563EB",
        "tone_base": 920.0,
        "clackiness": 0.92,
        "thockiness": 0.45,
        "click_intensity": 0.95,
        "spring_ping": 0.25,
        "damping": 32.0,
    },
    {
        "id": "cherry_mx_brown",
        "name": "Cherry MX Brown PBT",
        "category": "Tactile",
        "actuation_force": "45g actuation / 55g peak",
        "travel": "4.0mm",
        "description": "Subtle tactile bump with moderate bottom-out clack. Well-rounded, versatile everyday mechanical keyboard sound.",
        "color": "#92400E",
        "tone_base": 680.0,
        "clackiness": 0.72,
        "thockiness": 0.60,
        "click_intensity": 0.20,
        "spring_ping": 0.12,
        "damping": 36.0,
    },
    {
        "id": "cherry_mx_red",
        "name": "Cherry MX Red PBT",
        "category": "Linear",
        "actuation_force": "45g actuation",
        "travel": "4.0mm",
        "description": "Light, effortless linear switch. Clean, hollow-reduced bottom-out clack with swift return.",
        "color": "#DC2626",
        "tone_base": 720.0,
        "clackiness": 0.75,
        "thockiness": 0.55,
        "click_intensity": 0.0,
        "spring_ping": 0.10,
        "damping": 40.0,
    },
    {
        "id": "eg_crystal_purple",
        "name": "EG Crystal Purple",
        "category": "Tactile",
        "actuation_force": "67g bottom-out",
        "travel": "3.8mm",
        "description": "Everglide crystal transparent polycarbonate housing providing a bright, snappy tactile pop with clean acoustic definition.",
        "color": "#9333EA",
        "tone_base": 780.0,
        "clackiness": 0.85,
        "thockiness": 0.50,
        "click_intensity": 0.35,
        "spring_ping": 0.15,
        "damping": 34.0,
    },
    {
        "id": "gateron_black_ink",
        "name": "Gateron Black Ink",
        "category": "Linear",
        "actuation_force": "60g actuation / 70g bottom",
        "travel": "4.0mm",
        "description": "Famous proprietary Ink housing material creating one of the deepest, cleanest bass 'thocks' in mechanical keyboard acoustics.",
        "color": "#111827",
        "tone_base": 420.0,
        "clackiness": 0.55,
        "thockiness": 0.95,
        "click_intensity": 0.0,
        "spring_ping": 0.05,
        "damping": 44.0,
    },
    {
        "id": "gateron_red_ink",
        "name": "Gateron Red Ink V2",
        "category": "Linear",
        "actuation_force": "45g actuation / 60g bottom",
        "travel": "4.0mm",
        "description": "Velvety smooth lighter Ink linear switch with deep acoustic dampening and rich low-mid bottom-out resonance.",
        "color": "#EF4444",
        "tone_base": 520.0,
        "clackiness": 0.60,
        "thockiness": 0.88,
        "click_intensity": 0.0,
        "spring_ping": 0.06,
        "damping": 42.0,
    },
    {
        "id": "holy_panda",
        "name": "Holy Panda",
        "category": "Tactile",
        "actuation_force": "67g bottom-out",
        "travel": "3.8mm",
        "description": "Halo stem inside Invyr Panda nylon housing. Dramatic, explosive tactile bump with a loud, snappy bottom-out clack.",
        "color": "#F59E0B",
        "tone_base": 750.0,
        "clackiness": 0.92,
        "thockiness": 0.75,
        "click_intensity": 0.40,
        "spring_ping": 0.20,
        "damping": 32.0,
    },
    {
        "id": "kailh_box_navy",
        "name": "Kailh Box Navy",
        "category": "Thick Click",
        "actuation_force": "60g actuation / 90g bottom",
        "travel": "3.6mm",
        "description": "Equipped with an extra-thick torsion clickbar mechanism. Produces a loud, authoritative double-click that echoes off the plate.",
        "color": "#1E3A8A",
        "tone_base": 980.0,
        "clackiness": 0.98,
        "thockiness": 0.55,
        "click_intensity": 1.00,
        "spring_ping": 0.30,
        "damping": 26.0,
    },
    {
        "id": "nk_cream",
        "name": "NK Cream",
        "category": "Linear",
        "actuation_force": "55g actuation / 70g bottom",
        "travel": "4.0mm",
        "description": "Made entirely from self-lubricating POM thermoplastic. Produces a distinctive high-mid clack with unique acoustic density.",
        "color": "#FDE68A",
        "tone_base": 680.0,
        "clackiness": 0.85,
        "thockiness": 0.60,
        "click_intensity": 0.0,
        "spring_ping": 0.08,
        "damping": 38.0,
    },
    {
        "id": "topre",
        "name": "Topre PBT",
        "category": "Electrostatic",
        "actuation_force": "45g / 55g uniform",
        "travel": "4.0mm",
        "description": "Electrostatic capacitive rubber dome and conical spring mechanism. Iconic deep, muted, buttery 'thock' with no harsh metallic edges.",
        "color": "#6B7280",
        "tone_base": 360.0,
        "clackiness": 0.40,
        "thockiness": 0.98,
        "click_intensity": 0.0,
        "spring_ping": 0.04,
        "damping": 48.0,
    },
    {
        "id": "turquoise_tealios",
        "name": "Turquoise Tealios",
        "category": "Linear",
        "actuation_force": "63.5g bottom-out",
        "travel": "4.0mm",
        "description": "ZealPC custom polymer linear switch. Silky smooth travel with a refined, clear high-frequency housing clack.",
        "color": "#14B8A6",
        "tone_base": 660.0,
        "clackiness": 0.78,
        "thockiness": 0.65,
        "click_intensity": 0.0,
        "spring_ping": 0.08,
        "damping": 36.0,
    },
    {
        "id": "biscuit",
        "name": "Biscuit",
        "category": "Tactile",
        "actuation_force": "60g bottom-out",
        "travel": "3.5mm",
        "description": "Custom warm acoustic profile with softened bottom-out pads. Rich, pillowy tactile sensation with rounded low-frequency warmth.",
        "color": "#D97706",
        "tone_base": 460.0,
        "clackiness": 0.45,
        "thockiness": 0.92,
        "click_intensity": 0.15,
        "spring_ping": 0.06,
        "damping": 44.0,
    }
]

KEY_GROUPS = {
    "standard": {"freq_mult": 1.0, "decay_mult": 1.0, "low_boost": 1.0, "rattle": 0.0},
    "spacebar": {"freq_mult": 0.55, "decay_mult": 1.5, "low_boost": 1.8, "rattle": 0.15},
    "enter": {"freq_mult": 0.80, "decay_mult": 1.2, "low_boost": 1.3, "rattle": 0.06},
    "backspace": {"freq_mult": 0.90, "decay_mult": 1.08, "low_boost": 1.1, "rattle": 0.03},
    "modifier": {"freq_mult": 0.94, "decay_mult": 1.04, "low_boost": 1.05, "rattle": 0.02},
}

VELOCITY_TIERS = {
    "soft": {"gain": 0.65, "cutoff_mult": 0.85, "impact_mult": 0.7, "spring_mult": 0.4},
    "medium": {"gain": 0.85, "cutoff_mult": 1.0, "impact_mult": 1.0, "spring_mult": 0.75},
    "hard": {"gain": 1.05, "cutoff_mult": 1.25, "impact_mult": 1.3, "spring_mult": 1.1},
    "slam": {"gain": 1.25, "cutoff_mult": 1.5, "impact_mult": 1.7, "spring_mult": 1.6},
}

def generate_switch_sample(sw, kg_name, tier_name, is_release=False):
    kg = KEY_GROUPS[kg_name]
    tier = VELOCITY_TIERS[tier_name] if not is_release else {"gain": 0.45, "cutoff_mult": 0.9, "impact_mult": 0.5, "spring_mult": 0.25}
    
    duration = 0.085 if not is_release else 0.045
    if sw["id"] == "buckling_spring":
        duration += 0.06
    
    num_samples = int(SAMPLE_RATE * duration)
    samples_l = [0.0] * num_samples
    samples_r = [0.0] * num_samples
    
    base_f = sw["tone_base"] * kg["freq_mult"]
    damping = sw["damping"] / kg["decay_mult"]
    gain = tier["gain"]
    
    f1 = base_f * 0.85
    f2 = base_f * 1.75 * (1.0 + sw["clackiness"] * 0.35)
    f3 = base_f * 2.95 * (1.0 + sw["clackiness"] * 0.5)
    sub_f = base_f * 0.55
    
    jitter = random.uniform(0.985, 1.015)
    f1 *= jitter
    f2 *= jitter
    
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-damping * t * 16.0)
        
        # Primary body resonances
        body = (
            math.sin(2.0 * math.pi * f1 * t) * 0.75 +
            math.sin(2.0 * math.pi * f2 * t + 0.3) * sw["clackiness"] * 0.9 +
            math.sin(2.0 * math.pi * f3 * t + 0.7) * sw["clackiness"] * 0.5 +
            math.sin(2.0 * math.pi * sub_f * t) * sw["thockiness"] * kg["low_boost"] * 0.8
        ) * env
        
        # Transient impact pop (high frequency burst in first 4ms for crisp acoustic clarity)
        pop_env = math.exp(-t * 900.0)
        pop_noise = (random.random() * 2.0 - 1.0) * pop_env * (0.9 + sw["clackiness"] * 0.7) * tier["impact_mult"]
        
        # Clickleaf / Clickbar snap
        click = 0.0
        if sw["click_intensity"] > 0.0 and not is_release:
            click_t = t - 0.0012
            if click_t > 0.0:
                click_env = math.exp(-click_t * 2000.0)
                click_f = 3400.0 if sw["id"] != "kailh_box_navy" else 2600.0
                click = math.sin(2.0 * math.pi * click_f * click_t) * click_env * sw["click_intensity"] * 1.6
                click += (random.random() * 2.0 - 1.0) * click_env * sw["click_intensity"] * 0.6
        
        # Metallic Spring Ping
        ping = 0.0
        if sw["spring_ping"] > 0.0:
            ping_f = 2250.0 if sw["id"] == "buckling_spring" else 3500.0
            ping_env = math.exp(-t * 26.0) * sw["spring_ping"] * tier["spring_mult"]
            ping = math.sin(2.0 * math.pi * ping_f * t) * ping_env * 0.4
            if sw["id"] == "buckling_spring":
                ping += math.sin(2.0 * math.pi * (ping_f * 1.48) * t) * ping_env * 0.3
        
        # Stabilizer rattle
        rattle = 0.0
        if kg["rattle"] > 0.0 and tier_name in ["hard", "slam"]:
            rattle_t = t - 0.0025
            if rattle_t > 0.0:
                rattle_env = math.exp(-rattle_t * 550.0)
                rattle = (random.random() * 2.0 - 1.0) * rattle_env * kg["rattle"] * 1.2
        
        val = (body * 0.6 + pop_noise * 0.45 + click * 0.55 + ping * 0.35 + rattle * 0.3) * gain
        val = math.tanh(val * 1.6)
        
        pan = 0.5 + (random.random() - 0.5) * 0.06
        samples_l[i] = val * (1.0 - pan * 0.25)
        samples_r[i] = val * (1.0 - (1.0 - pan) * 0.25)
        
    return samples_l, samples_r

def write_wav(filepath, samples_l, samples_r):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with wave.open(filepath, 'w') as wav_file:
        wav_file.setnchannels(2)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        
        frames = bytearray()
        for l, r in zip(samples_l, samples_r):
            clamped_l = max(-1.0, min(1.0, l))
            clamped_r = max(-1.0, min(1.0, r))
            val_l = int(clamped_l * 32767.0)
            val_r = int(clamped_r * 32767.0)
            frames.extend(struct.pack('<hh', val_l, val_r))
        wav_file.writeframes(frames)

def main():
    target_dirs = [
        os.path.join(os.path.dirname(__file__), "..", "Sources", "Haptyk", "Resources", "SoundPacks"),
        os.path.join(os.path.dirname(__file__), "..", "Haptyk.app", "Contents", "Resources", "SoundPacks")
    ]
    
    for target_dir in target_dirs:
        os.makedirs(target_dir, exist_ok=True)
        manifest = []
        print(f"Generating enhanced sound packs in: {target_dir}")
        for sw in SWITCH_DEFINITIONS:
            pack_dir = os.path.join(target_dir, sw["id"])
            os.makedirs(pack_dir, exist_ok=True)
            
            for kg_name in KEY_GROUPS.keys():
                for tier_name in VELOCITY_TIERS.keys():
                    filename = f"{kg_name}_{tier_name}.wav"
                    filepath = os.path.join(pack_dir, filename)
                    sl, sr = generate_switch_sample(sw, kg_name, tier_name)
                    write_wav(filepath, sl, sr)
            
            rel_sl, rel_sr = generate_switch_sample(sw, "standard", "soft", is_release=True)
            write_wav(os.path.join(pack_dir, "release.wav"), rel_sl, rel_sr)
            
            info = {
                "id": sw["id"],
                "name": sw["name"],
                "category": sw["category"],
                "actuation_force": sw["actuation_force"],
                "travel": sw["travel"],
                "description": sw["description"],
                "color": sw["color"],
                "has_release": True,
                "tiers": ["soft", "medium", "hard", "slam"],
                "key_groups": list(KEY_GROUPS.keys())
            }
            with open(os.path.join(pack_dir, "info.json"), "w") as f:
                json.dump(info, f, indent=2)
            manifest.append(info)
            
        with open(os.path.join(target_dir, "manifest.json"), "w") as f:
            json.dump(manifest, f, indent=2)
            
    print("✓ All sound packs successfully regenerated with crisp acoustic clarity!")

if __name__ == "__main__":
    main()
