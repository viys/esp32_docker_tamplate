import sys
import re

def remove_comments(text):
    """去除 /* */ 块注释和 // 行注释"""
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    text = re.sub(r'//.*?$', '', text, flags=re.M)
    return text

def label_to_macro(label):
    # 直接转大写，不拆分数字
    return label.upper().replace("-", "_")

def parse_dts(dts_path):
    node_pattern = re.compile(r'(\w+)\s*:\s*(\w+)\s*\{([^}]*)\};', re.S)
    prop_pattern = re.compile(r'(\S+)\s*=\s*([^;]+);')

    with open(dts_path, "r", encoding="utf-8") as f:
        content = f.read()

    content = remove_comments(content)

    nodes = []
    for match in node_pattern.finditer(content):
        label = match.group(1)
        node_type = match.group(2)
        body = match.group(3)
        props = {}

        for pmatch in prop_pattern.finditer(body):
            key = pmatch.group(1)
            raw_val = pmatch.group(2).strip()

            if raw_val.startswith('<') and raw_val.endswith('>'):
                # 数字类型
                val = raw_val[1:-1]
                # 尝试转成数字，否则保持字符串
                if val.isdigit():
                    val = int(val)
            elif raw_val.startswith('"') and raw_val.endswith('"'):
                # 字符串，去引号
                val = raw_val[1:-1]
            else:
                # 其余类型如宏，保持原样
                val = raw_val

            props[key] = val

        nodes.append({
            "label": label,
            "type": node_type,
            "props": props
        })

    return nodes

def format_macro_value(val):
    if isinstance(val, int):
        return str(val)
    if isinstance(val, str):
        # 识别是否看起来像宏（全大写字母和数字开头，无引号），简单判断
        if re.match(r'^[A-Z0-9_]+$', val):
            return val
        return f'"{val}"'
    return f'"{val}"'

def generate_header(nodes, output_path):
    lines = []
    lines.append("/* Auto-generated devicetree header */\n")

    # 按类型分组
    type_groups = {}
    for node in nodes:
        t = node["type"]
        if t not in type_groups:
            type_groups[t] = []
        type_groups[t].append(node)

    for t, group_nodes in type_groups.items():
        lines.append(f"/** {t} **/")
        for node in group_nodes:
            macro_label = label_to_macro(node["label"])
            for k, v in node["props"].items():
                macro_name = k.upper().replace("-", "_")
                macro_val = format_macro_value(v)
                lines.append(f"#define DT_{macro_label}_{macro_name} {macro_val}")
        lines.append("")

    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"✅ Header generated at {output_path}")

def main():
    if len(sys.argv) != 3:
        print("Usage: python dts_parser.py <input.dts> <output.h>")
        sys.exit(1)

    dts_path = sys.argv[1]
    output_path = sys.argv[2]

    nodes = parse_dts(dts_path)
    generate_header(nodes, output_path)

if __name__ == "__main__":
    main()
