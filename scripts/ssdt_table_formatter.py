#!/usr/bin/env python3
"""
SSDT-style SQL Table Formatter

Formats CREATE TABLE statements to match Visual Studio SSDT conventions:
- Brackets around schema, table, column names, and data types
- Aligned columns (name, type, nullability, identity/default)
- 4-space indentation
- Uppercase keywords

Usage:
    python ssdt_table_formatter.py < input.sql > output.sql
    python ssdt_table_formatter.py input.sql
    python ssdt_table_formatter.py input.sql -o output.sql
"""

import re
import sys
import argparse
from dataclasses import dataclass
from typing import Optional


@dataclass
class ColumnDefinition:
    name: str
    data_type: str
    precision: Optional[str]  # e.g., "(255)" or "(18,2)"
    nullable: bool
    is_identity: bool
    default: Optional[str]
    comment: Optional[str]

    def formatted_name(self) -> str:
        return f"[{self.name}]"

    def formatted_type(self) -> str:
        base = f"[{self.data_type.upper()}]"
        if self.precision:
            return f"{base}{self.precision.upper()}"
        return base

    def formatted_constraints(self) -> str:
        parts = []
        parts.append("NOT NULL" if not self.nullable else "NULL")
        if self.is_identity:
            parts.append("IDENTITY")
        if self.default:
            parts.append(f"DEFAULT {self.default}")
        return " ".join(parts)


def bracket_identifier(name: str) -> str:
    """Add brackets around an identifier if not already bracketed."""
    name = name.strip()
    if name.startswith("[") and name.endswith("]"):
        return name
    # Remove existing brackets if malformed
    name = name.strip("[]")
    return f"[{name}]"


def parse_schema_table(header: str) -> tuple[str, str]:
    """Extract schema and table name from CREATE TABLE header."""
    # Match three-part names: [Database].[Schema].[Table]
    three_part = r"CREATE\s+TABLE\s+\[?\w+\]?\.\[?(\w+)\]?\.\[?(\w+)\]?"
    match = re.search(three_part, header, re.IGNORECASE)
    if match:
        return match.group(1), match.group(2)

    # Match two-part names: [Schema].[Table]
    two_part = r"CREATE\s+TABLE\s+\[?(\w+)\]?\.\[?(\w+)\]?"
    match = re.search(two_part, header, re.IGNORECASE)
    if match:
        return match.group(1), match.group(2)

    # Match single name: [Table] (default to dbo schema)
    single = r"CREATE\s+TABLE\s+\[?(\w+)\]?"
    match = re.search(single, header, re.IGNORECASE)
    if match:
        return "dbo", match.group(1)

    raise ValueError(f"Could not parse table name from: {header}")


def parse_data_type(type_str: str) -> tuple[str, Optional[str]]:
    """Parse data type and precision from a type string."""
    type_str = type_str.strip().strip("[]")

    # Match type with precision: nvarchar(255), decimal(18,2), datetime2(6)
    match = re.match(r"(\w+)(\([^)]+\))?", type_str, re.IGNORECASE)
    if match:
        base_type = match.group(1)
        precision = match.group(2)
        return base_type, precision
    return type_str, None


def parse_column_definition(line: str) -> Optional[ColumnDefinition]:
    """Parse a single column definition line."""
    line = line.strip()

    # Skip empty lines, comments only, constraint lines
    if not line or line.startswith("--") or line.startswith("/*"):
        return None
    if re.match(r"^\s*(CONSTRAINT|PRIMARY\s+KEY|FOREIGN\s+KEY|UNIQUE|CHECK|INDEX)", line, re.IGNORECASE):
        return None
    if line in ("(", ")", ");", "GO"):
        return None

    # Remove trailing comma
    line = line.rstrip(",")

    # Extract inline comment
    comment = None
    comment_match = re.search(r"--(.*)$", line)
    if comment_match:
        comment = comment_match.group(1).strip()
        line = line[:comment_match.start()].strip()

    # Parse column: [Name] [type](precision) NOT NULL IDENTITY DEFAULT value
    # More flexible pattern to handle various formats
    pattern = r"""
        ^\s*
        \[?(\w+)\]?\s+                     # Column name
        \[?(\w+)\]?(\([^)]+\))?\s*         # Data type with optional precision
        (NOT\s+NULL|NULL)?\s*              # Nullability
        (IDENTITY(?:\s*\(\d+,\s*\d+\))?)?\s*  # Identity with optional seed
        (DEFAULT\s+.+)?                    # Default value
        $
    """

    match = re.match(pattern, line, re.IGNORECASE | re.VERBOSE)
    if not match:
        # Try simpler pattern for basic columns
        simple_pattern = r"^\s*\[?(\w+)\]?\s+\[?(\w+)\]?(\([^)]+\))?"
        simple_match = re.match(simple_pattern, line, re.IGNORECASE)
        if simple_match:
            name = simple_match.group(1)
            data_type = simple_match.group(2)
            precision = simple_match.group(3)

            # Check for nullability, identity, default in remaining text
            remainder = line[simple_match.end():].upper()
            nullable = "NOT NULL" not in remainder
            is_identity = "IDENTITY" in remainder

            default = None
            default_match = re.search(r"DEFAULT\s+(.+?)(?:\s*$)", line[simple_match.end():], re.IGNORECASE)
            if default_match:
                default = default_match.group(1).strip()

            return ColumnDefinition(
                name=name,
                data_type=data_type,
                precision=precision,
                nullable=nullable,
                is_identity=is_identity,
                default=default,
                comment=comment
            )
        return None

    name = match.group(1)
    data_type = match.group(2)
    precision = match.group(3)
    null_clause = match.group(4)
    identity_clause = match.group(5)
    default_clause = match.group(6)

    nullable = True
    if null_clause:
        nullable = "NOT" not in null_clause.upper()

    is_identity = bool(identity_clause)

    default = None
    if default_clause:
        default = re.sub(r"^DEFAULT\s+", "", default_clause, flags=re.IGNORECASE).strip()

    return ColumnDefinition(
        name=name,
        data_type=data_type,
        precision=precision,
        nullable=nullable,
        is_identity=is_identity,
        default=default,
        comment=comment
    )


def format_table(sql: str) -> str:
    """Format a CREATE TABLE statement to SSDT style."""
    lines = sql.split("\n")

    # Find the CREATE TABLE line
    header_idx = -1
    for i, line in enumerate(lines):
        if re.search(r"CREATE\s+TABLE", line, re.IGNORECASE):
            header_idx = i
            break

    if header_idx == -1:
        return sql  # Not a CREATE TABLE, return as-is

    # Parse schema and table name
    header_line = lines[header_idx]
    try:
        schema, table = parse_schema_table(header_line)
    except ValueError:
        return sql

    # Find column definitions (between opening and closing parentheses)
    paren_start = -1
    paren_end = -1
    paren_depth = 0

    for i, line in enumerate(lines[header_idx:], start=header_idx):
        for char in line:
            if char == "(":
                if paren_depth == 0:
                    paren_start = i
                paren_depth += 1
            elif char == ")":
                paren_depth -= 1
                if paren_depth == 0:
                    paren_end = i
                    break
        if paren_end != -1:
            break

    if paren_start == -1 or paren_end == -1:
        return sql

    # Extract column definition lines
    column_lines = []
    for i in range(paren_start, paren_end + 1):
        line = lines[i]
        # Skip the opening paren line if it's on the header
        if i == paren_start and "(" in line:
            # Get content after the opening paren
            paren_pos = line.index("(")
            after_paren = line[paren_pos + 1:].strip()
            if after_paren:
                column_lines.append(after_paren)
        elif i == paren_end:
            # Get content before the closing paren
            if ")" in line:
                paren_pos = line.index(")")
                before_paren = line[:paren_pos].strip()
                if before_paren:
                    column_lines.append(before_paren)
        else:
            column_lines.append(line)

    # Parse columns
    columns: list[ColumnDefinition] = []
    constraint_lines: list[str] = []
    comment_lines: list[tuple[int, str]] = []  # (insert_after_index, comment)

    for line in column_lines:
        stripped = line.strip().rstrip(",")

        # Preserve standalone comments
        if stripped.startswith("--"):
            comment_lines.append((len(columns), stripped))
            continue

        # Check for constraints
        if re.match(r"^\s*(CONSTRAINT|PRIMARY\s+KEY|FOREIGN\s+KEY|UNIQUE|CHECK)", stripped, re.IGNORECASE):
            constraint_lines.append(stripped)
            continue

        col = parse_column_definition(line)
        if col:
            columns.append(col)

    if not columns:
        return sql

    # Calculate column widths for alignment
    max_name_width = max(len(col.formatted_name()) for col in columns)
    max_type_width = max(len(col.formatted_type()) for col in columns)

    # Build formatted output
    output_lines = []
    output_lines.append(f"CREATE TABLE [{schema}].[{table}] (")

    # Track where to insert comments
    comment_dict: dict[int, list[str]] = {}
    for idx, comment in comment_lines:
        if idx not in comment_dict:
            comment_dict[idx] = []
        comment_dict[idx].append(comment)

    for i, col in enumerate(columns):
        # Insert any comments before this column
        if i in comment_dict:
            for comment in comment_dict[i]:
                output_lines.append(f"    {comment}")

        name_part = col.formatted_name().ljust(max_name_width)
        type_part = col.formatted_type().ljust(max_type_width)
        constraint_part = col.formatted_constraints()

        # Add trailing comma except for last column (if no constraints follow)
        is_last = (i == len(columns) - 1) and not constraint_lines
        comma = "" if is_last else ","

        # Add inline comment if present
        comment_suffix = f"  -- {col.comment}" if col.comment else ""

        output_lines.append(f"    {name_part} {type_part} {constraint_part}{comma}{comment_suffix}")

    # Add comments after last column
    if len(columns) in comment_dict:
        for comment in comment_dict[len(columns)]:
            output_lines.append(f"    {comment}")

    # Add constraints
    for i, constraint in enumerate(constraint_lines):
        is_last = i == len(constraint_lines) - 1
        comma = "" if is_last else ","
        output_lines.append(f"    {constraint}{comma}")

    output_lines.append(")")

    # Add GO and any statements after the table definition
    go_idx = -1
    for i, line in enumerate(lines[paren_end + 1:], start=paren_end + 1):
        if line.strip().upper() == "GO":
            go_idx = i
            break

    if go_idx != -1:
        output_lines.append("GO")
        # Include any remaining lines (constraints, indexes, etc.)
        for line in lines[go_idx + 1:]:
            if line.strip():
                output_lines.append(line)

    return "\n".join(output_lines)


def format_sql_file(content: str) -> str:
    """Format all CREATE TABLE statements in a SQL file."""
    # Split by GO statements to handle multiple tables
    # Use regex to find CREATE TABLE blocks

    # For now, handle the content as a single table
    # TODO: Handle multiple CREATE TABLE statements
    return format_table(content)


def main():
    parser = argparse.ArgumentParser(
        description="Format SQL CREATE TABLE statements to SSDT style"
    )
    parser.add_argument(
        "input",
        nargs="?",
        help="Input SQL file (reads from stdin if not provided)"
    )
    parser.add_argument(
        "-o", "--output",
        help="Output file (writes to stdout if not provided)"
    )
    args = parser.parse_args()

    # Read input
    if args.input:
        with open(args.input, "r", encoding="utf-8") as f:
            content = f.read()
    else:
        content = sys.stdin.read()

    # Format
    result = format_sql_file(content)

    # Write output
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(result)
    else:
        print(result)


if __name__ == "__main__":
    main()
