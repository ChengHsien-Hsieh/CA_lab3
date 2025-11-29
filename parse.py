import re

def parse_synth_log(filepath):
    module_pattern = re.compile(r"^===\s+(\S+)\s+===")
    area_pattern = re.compile(r"Chip area for module '\\(\S+)':\s+([\d.]+)")
    latch_no_pattern = re.compile(r"^No latch inferred")
    latch_yes_pattern = re.compile(r"^Latch inferred")
    
    # 匹配 "10.6." 或 "13.6." 等任意數字開頭的 PROC_DLATCH pass
    dlatch_start_pattern = re.compile(r"^\s*\d+\.\d+\.\s+Executing PROC_DLATCH pass")

    module_areas = {}
    current_module = None
    latch_no_count = 0
    latch_yes_count = 0
    inside_dlatch_section = False

    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()

            # 檢查是否進入 PROC_DLATCH section
            if dlatch_start_pattern.match(line):
                inside_dlatch_section = True
                continue
            
            # 檢查是否離開 section (遇到下一個數字標題時)
            if inside_dlatch_section and re.match(r"^\d+\.", line):
                inside_dlatch_section = False

            # 統計 latch
            if inside_dlatch_section:
                if latch_no_pattern.match(line):
                    latch_no_count += 1
                elif latch_yes_pattern.match(line):
                    latch_yes_count += 1

            # 抓 module
            m = module_pattern.match(line)
            if m:
                current_module = m.group(1)
                continue

            # 抓面積
            a = area_pattern.match(line)
            if a:
                module_name = a.group(1)
                area = float(a.group(2))
                module_areas[module_name] = area

    total_area = sum(module_areas.values())

    print("=== Module Areas ===")
    for m, a in module_areas.items():
        print(f"{m}: {a:.3f}")
    print("====================")
    print(f"Total area: {total_area:.3f}\n")

    print("=== Latch Statistics (PROC_DLATCH pass) ===")
    print(f"No latch inferred count : {latch_no_count}")
    print(f"Latch inferred count    : {latch_yes_count}")
    print()

if __name__ == "__main__":
    print("=" * 60)
    print("CPU Synthesis Log Analysis")
    print("=" * 60)
    parse_synth_log("./log/cpu_syn.log")
    
    print("\n" + "=" * 60)
    print("Cache Synthesis Log Analysis")
    print("=" * 60)
    parse_synth_log("./log/cache_syn.log")
