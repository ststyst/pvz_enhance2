"""把同一文件夹内尺寸相同的图片按顺序无缝横向拼接成一张长条 PNG。

用法:
    python tools/merge_strip.py <输入文件夹> <输出图片路径> [选项]

选项:
    --pattern "*.png"   只匹配指定文件名通配符（默认按扩展名收集全部图片）
    --exclude "*副本*"   排除匹配的文件，可重复使用多次
    --sort natural      排序方式: natural(默认, 1,2,...,10) / name(字典序) / mtime(修改时间)
    --force             允许覆盖已存在的输出文件
    --dry-run           只做检查并打印计划，不写文件

示例:
    python tools/merge_strip.py assets/reanim/frames assets/reanim/strip.png
    python tools/merge_strip.py . ./walk_strip.png --pattern "walk_*.png" --sort name
    python tools/merge_strip.py . ./strip.png --exclude "*副本*"

说明:
    1. 所有图片必须尺寸一致，否则报错并列出不一致的尺寸分组；
    2. 输出为 RGBA PNG，逐像素复制，不做任何缩放或重采样，因此是真正的无缝拼接；
    3. 若输出文件位于输入文件夹内，会被自动排除，重复运行不会把上一次的结果拼进去；
    4. 导入 Godot 后，横向长条可直接给 Sprite2D/SpriteFrames 用 hframes = 帧数、vframes = 1。
"""

import argparse
import fnmatch
import re
import sys
from pathlib import Path

from PIL import Image

# Windows 下通过管道或重定向运行时 stdout 可能是 GBK，统一成 UTF-8，避免中文报告乱码。
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

# Pillow 能读的常见位图扩展名；实际以能否打开为准，这里只做初筛。
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga", ".gif"}


def natural_key(text: str):
    """把文件名切成数字段与非数字段，用于 1,2,10 的自然排序。"""
    # 数字段转成整数参与比较，其余转小写，避免大小写影响顺序。
    return [int(part) if part.isdigit() else part.lower() for part in re.split(r"(\d+)", text)]


def collect_images(folder: Path, pattern: str, output: Path, excludes: list) -> list:
    """收集文件夹内的候选图片，排除输出文件与排除规则命中的文件。"""
    images = []
    for path in folder.iterdir():
        if not path.is_file():
            continue
        if path.suffix.lower() not in IMAGE_SUFFIXES:
            continue
        if pattern and not fnmatch.fnmatch(path.name, pattern):
            continue
        # 输出文件可能就在输入目录里，必须排除，否则重跑会把上次结果拼进来。
        if path.resolve() == output.resolve():
            continue
        # 排除规则用于剔除副本等不应参与拼接的文件。
        if any(fnmatch.fnmatch(path.name, rule) for rule in excludes):
            continue
        images.append(path)
    return images


def count_excluded(folder: Path, output: Path, excludes: list) -> int:
    """统计被排除规则命中的图片数量，仅用于报告。"""
    if not excludes:
        return 0
    count = 0
    for path in folder.iterdir():
        if not path.is_file() or path.suffix.lower() not in IMAGE_SUFFIXES:
            continue
        if path.resolve() == output.resolve():
            continue
        if any(fnmatch.fnmatch(path.name, rule) for rule in excludes):
            count += 1
    return count


def sort_images(images: list, mode: str) -> list:
    """按 [mode] 排序；natural 处理 1/2/10，name 为纯字典序，mtime 按修改时间。"""
    if mode == "name":
        return sorted(images, key=lambda p: p.name.lower())
    if mode == "mtime":
        return sorted(images, key=lambda p: p.stat().st_mtime)
    return sorted(images, key=lambda p: natural_key(p.name))


def open_size(path: Path):
    """返回图片的 (宽, 高)；打不开时抛出带文件名的错误。"""
    try:
        with Image.open(path) as image:
            return image.size
    except OSError as error:
        raise SystemExit(f"无法读取图片: {path}（{error}）") from error


def validate_sizes(images: list) -> tuple:
    """校验尺寸一致并返回统一的 (宽, 高)；不一致时列出分组明细后退出。"""
    size_groups = {}
    for path in images:
        size_groups.setdefault(open_size(path), []).append(path.name)
    if len(size_groups) > 1:
        lines = ["图片尺寸不一致，无法无缝拼接："]
        for (width, height), names in sorted(size_groups.items(), key=lambda item: item[0]):
            sample = "、".join(names[:3]) + ("……" if len(names) > 3 else "")
            lines.append(f"  {width}x{height}: {len(names)} 张（{sample}）")
        raise SystemExit("\n".join(lines))
    return next(iter(size_groups))


def merge_horizontal(images: list, frame_size: tuple, output: Path) -> tuple:
    """按顺序把图片逐像素横向拼到同一张 RGBA 画布上，返回输出尺寸。"""
    frame_width, frame_height = frame_size
    strip_width = frame_width * len(images)
    canvas = Image.new("RGBA", (strip_width, frame_height), (0, 0, 0, 0))
    x_offset = 0
    for path in images:
        with Image.open(path) as image:
            # 统一转 RGBA，让带透明通道和不带通道的图片都能正确叠加。
            canvas.paste(image.convert("RGBA"), (x_offset, 0))
        x_offset += frame_width
    # 输出目录可能不存在，先建好再写。
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, format="PNG")
    return (strip_width, frame_height)


def parse_args(argv) -> argparse.Namespace:
    """解析命令行参数；输入目录与输出路径为必填。"""
    parser = argparse.ArgumentParser(
        description="把尺寸相同的图片无缝横向拼接成一张长条 PNG。",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("folder", type=Path, help="输入文件夹")
    parser.add_argument("output", type=Path, help="输出 PNG 路径")
    parser.add_argument("--pattern", default="", help='文件名通配符，例如 "walk_*.png"')
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        help='排除匹配的文件，可重复，例如 --exclude "*副本*"',
    )
    parser.add_argument(
        "--sort",
        default="natural",
        choices=["natural", "name", "mtime"],
        help="排序方式，默认 natural",
    )
    parser.add_argument("--force", action="store_true", help="允许覆盖已存在的输出文件")
    parser.add_argument("--dry-run", action="store_true", help="只检查并打印计划，不写文件")
    return parser.parse_args(argv)


def main(argv) -> int:
    """执行收集、校验、拼接与报告；任何前置检查失败都以非零码退出。"""
    args = parse_args(argv)
    folder = args.folder.expanduser().resolve()
    output = args.output.expanduser().resolve()

    if not folder.is_dir():
        raise SystemExit(f"输入文件夹不存在: {folder}")
    if output.suffix.lower() != ".png":
        raise SystemExit("输出文件必须是 .png，便于 Godot 无损导入。")
    if output.exists() and not args.force:
        raise SystemExit(f"输出文件已存在，如需覆盖请加 --force: {output}")

    images = sort_images(collect_images(folder, args.pattern, output, args.exclude), args.sort)
    if not images:
        raise SystemExit(f"文件夹内没有匹配的图片: {folder}（pattern={args.pattern or '全部'}）")

    frame_size = validate_sizes(images)
    frame_width, frame_height = frame_size
    strip_size = (frame_width * len(images), frame_height)
    excluded_count = count_excluded(folder, output, args.exclude)

    print(f"输入文件夹: {folder}")
    print(f"匹配图片  : {len(images)} 张")
    print(f"排除规则  : {'、'.join(args.exclude) if args.exclude else '无'}（已排除 {excluded_count} 张）")
    print(f"单帧尺寸  : {frame_width} x {frame_height}")
    print(f"输出尺寸  : {strip_size[0]} x {strip_size[1]}")
    print(f"排序方式  : {args.sort}")
    print("拼接顺序  :")
    for index, path in enumerate(images, start=1):
        print(f"  {index:>3}. {path.name}")

    if args.dry_run:
        print("dry-run：未写文件。")
        return 0

    result_size = merge_horizontal(images, frame_size, output)
    print(f"已生成    : {output}（{result_size[0]} x {result_size[1]}，{len(images)} 帧）")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
