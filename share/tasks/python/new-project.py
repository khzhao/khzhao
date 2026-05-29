# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tomllib
from dataclasses import dataclass
from pathlib import Path
from textwrap import dedent


DEFAULT_BASES = {
    "python": "package",
    "cpp": "project",
}

DEFAULT_COMPONENTS = {
    "python": "ipykernel,ruff,pre-commit,pyrefly,pytest",
}

VARIABLES = (
    "project_name",
    "project_slug",
    "package_name",
    "python_tool_sections",
)


@dataclass(frozen=True)
class Base:
    name: str
    description: str


@dataclass(frozen=True)
class Component:
    name: str
    allowed_bases: tuple[str, ...]
    requires: tuple[str, ...]
    description: str


def die(message: str) -> None:
    raise SystemExit(message)


def split_csv(value: str) -> tuple[str, ...]:
    if not value or value == "*":
        return ()
    return tuple(item.strip() for item in value.split(",") if item.strip())


def load_bases(path: Path) -> dict[str, Base]:
    bases: dict[str, Base] = {}

    for line in path.read_text().splitlines():
        if not line or line.startswith("#") or line.startswith("name|"):
            continue

        fields = line.split("|")
        if len(fields) != 2:
            die(f"Invalid bases row in {path}: {line}")

        name, description = fields
        bases[name] = Base(name=name, description=description)

    return bases


def load_components(path: Path) -> dict[str, Component]:
    components: dict[str, Component] = {}

    if not path.exists():
        return components

    for line in path.read_text().splitlines():
        if not line or line.startswith("#") or line.startswith("name|"):
            continue

        fields = line.split("|")
        if len(fields) != 4:
            die(f"Invalid components row in {path}: {line}")

        name, allowed_bases, requires, description = fields
        components[name] = Component(
            name=name,
            allowed_bases=("*",) if allowed_bases == "*" else split_csv(allowed_bases),
            requires=split_csv(requires),
            description=description,
        )

    return components


def project_slug(name: str) -> str:
    return re.sub(r"[ _]+", "-", name.lower()).strip("-")


def package_name(name: str) -> str:
    return re.sub(r"[ -]+", "_", name.lower()).strip("_")


def render_text(text: str, context: dict[str, str]) -> str:
    for key in VARIABLES:
        text = text.replace("{{" + key + "}}", context.get(key, ""))
    return text


def selected_components(value: str, components: dict[str, Component]) -> list[str]:
    requested: list[str] = []
    seen: set[str] = set()

    for component in split_csv(value):
        if component in seen:
            continue
        requested.append(component)
        seen.add(component)

    known = [name for name in components if name in seen]
    unknown = [name for name in requested if name not in components]
    return [*known, *unknown]


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def family_root(family: str) -> Path:
    return repo_root() / "share" / "templates" / "project" / family


def validate_project_name(name: str) -> None:
    if "/" in name or "\\" in name:
        die("Project name must not contain path separators.")
    if name in {".", ".."}:
        die("Project name must not be . or ..")
    if not project_slug(name) or not package_name(name):
        die("Project name must contain at least one letter, number, hyphen, underscore, or space.")


def component_supports_base(component: Component, base: str) -> bool:
    return component.allowed_bases == ("*",) or base in component.allowed_bases


def format_allowed_bases(component: Component) -> str:
    if component.allowed_bases == ("*",):
        return "all bases"
    return "\n".join(f"  {base}" for base in component.allowed_bases)


def validate_selection(
    family: str,
    root: Path,
    bases: dict[str, Base],
    components: dict[str, Component],
    base: str,
    selected: list[str],
    raw_name: str,
    force: bool,
) -> Path:
    if base not in bases:
        die(f"Unknown base `{base}` for family `{family}`.")

    base_dir = root / "bases" / base
    if not base_dir.is_dir():
        die(f"Base `{base}` is missing directory: {base_dir}")

    for name in selected:
        if name not in components:
            die(f"Unknown component `{name}` for family `{family}`.")

        component_dir = root / "components" / name
        if not component_dir.is_dir():
            die(f"Component `{name}` is missing directory: {component_dir}")

        component = components[name]
        if not component_supports_base(component, base):
            die(
                f"Component `{name}` is not compatible with base `{base}`.\n\n"
                "Allowed bases:\n"
                f"{format_allowed_bases(component)}"
            )

    selected_set = set(selected)
    for name in selected:
        component = components[name]
        for required in component.requires:
            if required not in selected_set:
                suggestion = ",".join([required, *selected])
                die(
                    f"Component `{name}` requires component `{required}`.\n\n"
                    "Try:\n"
                    f"  khzhao run new-project {family} <name> --base {base} --with {suggestion}"
                )

    output_dir = Path(project_slug(raw_name))
    if output_dir.exists() and not force:
        die(f"Target project directory already exists: {output_dir}")

    return output_dir


def copy_tree(source: Path, target: Path, force: bool) -> None:
    for source_path in source.rglob("*"):
        relative_path = source_path.relative_to(source)
        target_path = target / relative_path

        if source_path.is_dir():
            target_path.mkdir(parents=True, exist_ok=True)
            continue

        if target_path.exists() and not force:
            die(f"Refusing to overwrite existing file: {target_path}")

        target_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_path, target_path)


def read_fragment(path: Path, context: dict[str, str]) -> str:
    if not path.is_file():
        return ""

    return render_text(path.read_text(), context).strip("\n")


def build_context(root: Path, selected: list[str], raw_name: str) -> dict[str, str]:
    context = {
        "project_name": raw_name,
        "project_slug": project_slug(raw_name),
        "package_name": package_name(raw_name),
        "python_tool_sections": "",
    }

    python_tool_sections: list[str] = []

    for name in selected:
        python_tool_section = read_fragment(
            root / "components" / name / "pyproject.toml.tmpl",
            context,
        )
        if python_tool_section:
            python_tool_sections.append(python_tool_section)

    context["python_tool_sections"] = "\n\n".join(python_tool_sections)
    return context


def collect_python_packages(root: Path, selected: list[str]) -> tuple[list[str], list[str]]:
    main_packages: list[str] = []
    dev_packages: list[str] = []
    seen_main: set[str] = set()
    seen_dev: set[str] = set()

    for name in selected:
        path = root / "components" / name / "packages.psv"
        if not path.is_file():
            continue

        for line in path.read_text().splitlines():
            if not line or line.startswith("#") or line.startswith("group|"):
                continue

            fields = line.split("|")
            if len(fields) != 2:
                die(f"Invalid package row in {path}: {line}")

            group, package = fields
            if group == "main":
                if package not in seen_main:
                    main_packages.append(package)
                    seen_main.add(package)
            elif group == "dev":
                if package not in seen_dev:
                    dev_packages.append(package)
                    seen_dev.add(package)
            else:
                die(f"Unsupported package group `{group}` in {path}.")

    return main_packages, dev_packages


def pin_python_packages(target: Path, packages: list[str], dev: bool) -> None:
    if not packages:
        return

    if not shutil.which("uv"):
        die("Cannot pin latest Python dependencies because uv was not found on PATH.")

    command = [
        "uv",
        "add",
        "--bounds",
        "lower",
        "--upgrade",
        "--no-sync",
    ]
    if dev:
        command.append("--dev")
    command.extend(packages)

    env = os.environ.copy()
    env.pop("VIRTUAL_ENV", None)

    try:
        subprocess.run(command, cwd=target, check=True, env=env)
    except subprocess.CalledProcessError as error:
        die(f"Failed to pin latest Python dependencies with uv add: exit {error.returncode}")


def pinned_package_version(target: Path, package_name: str) -> str:
    pyproject_path = target / "pyproject.toml"
    if not pyproject_path.is_file():
        return ""

    data = tomllib.loads(pyproject_path.read_text())
    requirements = list(data.get("project", {}).get("dependencies", []))
    for group in data.get("dependency-groups", {}).values():
        if isinstance(group, list):
            requirements.extend(item for item in group if isinstance(item, str))

    for requirement in requirements:
        match = re.match(rf"^{re.escape(package_name)}>=([^,;\\s]+)", requirement)
        if match:
            return match.group(1)

    return ""


def render_late_templates(target: Path) -> None:
    ruff_version = pinned_package_version(target, "ruff")

    for path in target.rglob("*"):
        if not path.is_file():
            continue

        try:
            text = path.read_text()
        except UnicodeDecodeError:
            continue

        if "{{ruff_version}}" not in text:
            continue
        if not ruff_version:
            die(f"Cannot render {path}: Ruff version was not found in pyproject.toml.")

        path.write_text(text.replace("{{ruff_version}}", ruff_version))


def render_path_name(name: str, context: dict[str, str]) -> str:
    rendered = render_text(name, context)
    if rendered.endswith(".tmpl"):
        rendered = rendered[:-5]
    return rendered


def move_path(path: Path, target: Path, force: bool) -> Path:
    if target == path:
        return target

    if target.exists():
        if not force:
            die(f"Refusing to overwrite rendered path: {target}")
        if target.is_dir():
            shutil.rmtree(target)
        else:
            target.unlink()

    target.parent.mkdir(parents=True, exist_ok=True)
    path.rename(target)
    return target


def render_project_tree(target: Path, context: dict[str, str], force: bool) -> None:
    for path in sorted(target.rglob("*"), key=lambda item: len(item.parts), reverse=True):
        if path.is_file() and path.name.endswith(".tmpl"):
            final_name = render_path_name(path.name, context)
            final_path = path.with_name(final_name)
            rendered = render_text(path.read_text(), context)
            if final_path.exists() and final_path != path and not force:
                die(f"Refusing to overwrite rendered file: {final_path}")
            final_path.write_text(rendered)
            if final_path != path:
                path.unlink()
            path = final_path

        rendered_name = render_path_name(path.name, context)
        if rendered_name != path.name:
            move_path(path, path.with_name(rendered_name), force)


def list_bases(family: str, bases: dict[str, Base]) -> None:
    print(f"Bases for {family}:")
    for base in bases.values():
        print(f"  {base.name} - {base.description}")


def list_components(family: str, components: dict[str, Component]) -> None:
    print(f"Components for {family}:")
    if not components:
        print("  none")
        return

    for component in components.values():
        allowed = "*" if component.allowed_bases == ("*",) else ",".join(component.allowed_bases)
        print(f"  {component.name} (bases: {allowed}) - {component.description}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="new-project",
        description="Create a project from khzhao templates.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=dedent(
            """\
            defaults:
              python: base package, components ipykernel,ruff,pre-commit,pyrefly,pytest
              cpp:    base project, no components

            examples:
              new-project python mypkg
              new-project python mypkg --with ruff,pytest
              new-project cpp mylib
              new-project python --list-components
              new-project cpp --list-bases
            """
        ),
    )
    parser.add_argument("family")
    parser.add_argument("project_name", nargs="?")
    parser.add_argument("--base", help="template base to use")
    parser.add_argument("--with", dest="components", default="", help="comma-separated components")
    parser.add_argument("--force", action="store_true", help="overwrite the target project directory")
    parser.add_argument("--list-bases", action="store_true", help="list bases for the selected family")
    parser.add_argument("--list-components", action="store_true", help="list components for the selected family")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = family_root(args.family)

    if not root.is_dir():
        die(f"Unknown project family `{args.family}`.")

    bases = load_bases(root / "bases.psv")
    components = load_components(root / "components.psv")

    if args.list_bases and args.list_components:
        die("Use only one of --list-bases or --list-components.")
    if args.list_bases:
        list_bases(args.family, bases)
        return 0
    if args.list_components:
        list_components(args.family, components)
        return 0

    if not args.project_name:
        die("usage: new-project <family> <project_name> --base <base> --with <components>")

    validate_project_name(args.project_name)
    base = args.base or DEFAULT_BASES.get(args.family)
    if not base:
        die(f"No default base configured for family `{args.family}`.")

    component_arg = args.components or DEFAULT_COMPONENTS.get(args.family, "")
    selected = selected_components(component_arg, components)
    output_dir = validate_selection(
        args.family,
        root,
        bases,
        components,
        base,
        selected,
        args.project_name,
        args.force,
    )

    if output_dir.exists() and args.force:
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True)

    copy_tree(root / "bases" / base, output_dir, args.force)
    for name in selected:
        files_dir = root / "components" / name / "files"
        if files_dir.is_dir():
            copy_tree(files_dir, output_dir, args.force)

    context = build_context(root, selected, args.project_name)
    render_project_tree(output_dir, context, args.force)
    main_packages, dev_packages = collect_python_packages(root, selected)
    pin_python_packages(output_dir, main_packages, dev=False)
    pin_python_packages(output_dir, dev_packages, dev=True)
    render_late_templates(output_dir)

    print(f"Created {args.family} project: {output_dir}")
    print(f"  base: {base}")
    if selected:
        print(f"  components: {', '.join(selected)}")
    else:
        print("  components: none")

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
