# UNIX Philosophy in Universal Bookmarks

This document explains how the Universal Bookmarks project applies UNIX philosophy and functional programming principles to create maintainable, composable, and elegant code.

## Core Principles Applied

### 1. Do One Thing Well

Each function in the codebase has a single, clear responsibility:

- `detect_system_opener()` - Only detects the system opener command
- `filter_by_type()` - Only filters bookmarks by type
- `calculate_frecency()` - Only calculates a frecency score

This makes functions easy to understand, test, and reuse.

### 2. Compose Simple Tools

Complex behavior emerges from composing simple parts through pipes:

```bash
# Complex query built from simple filters
filter_all_bookmarks | \
  filter_active | \
  filter_by_type "url" | \
  filter_by_tag "work" | \
  sort_by_frecency | \
  format_bookmark_line
```

### 3. Text Streams as Interface

Functions use text streams (JSON, TSV) as their universal interface, enabling composition:

```bash
# JSON stream input/output
filter_all_bookmarks | jq '.description'

# TSV for traditional UNIX tools
filter_all_bookmarks | to_tsv | awk -F'\t' '{print $2}'
```

### 4. Separation of Mechanism and Policy

The code provides mechanisms (tools), users define policy (how to use them):

- **Mechanism**: `filter_by_type`, `filter_by_tag`
- **Policy**: Users decide which filters to combine and in what order

## Composable Filter Functions

The heart of the UNIX philosophy implementation is the composable filter library.

### Filter Pattern

All filter functions follow this pattern:

```bash
# Pattern: Read from stdin, write to stdout
input_stream | filter_function [args] | output_stream
```

### Available Filters

#### Data Extraction Filters

**`filter_all_bookmarks`**
- Input: None (reads from $BOOKMARKS_FILE)
- Output: JSON stream (one bookmark per line)
- Example: `filter_all_bookmarks | wc -l`

**`filter_active`**
- Input: JSON bookmark stream
- Output: Filtered JSON bookmark stream (excludes obsolete)
- Example: `filter_all_bookmarks | filter_active`

**`filter_by_type <type>`**
- Input: JSON bookmark stream
- Args: bookmark type (url, script, pdf, etc.)
- Output: Filtered JSON bookmark stream
- Example: `filter_all_bookmarks | filter_by_type "url"`

**`filter_by_tag <tag>`**
- Input: JSON bookmark stream
- Args: tag to search for (partial match)
- Output: Filtered JSON bookmark stream
- Example: `filter_all_bookmarks | filter_by_tag "work"`

**`filter_by_status <status>`**
- Input: JSON bookmark stream
- Args: status (active, obsolete)
- Output: Filtered JSON bookmark stream
- Example: `filter_all_bookmarks | filter_by_status "active"`

#### Transformation Filters

**`extract_field <field>`**
- Input: JSON bookmark stream
- Args: field name to extract
- Output: Field values (one per line)
- Example: `filter_all_bookmarks | extract_field "description"`

**`format_bookmark_line`**
- Input: JSON bookmark stream
- Output: Human-readable format "[type] description"
- Example: `filter_all_bookmarks | format_bookmark_line`

**`sort_by_frecency`**
- Input: JSON bookmark stream
- Output: Sorted JSON bookmark stream (by frecency score, descending)
- Example: `filter_all_bookmarks | sort_by_frecency`

**`to_tsv`**
- Input: JSON bookmark stream
- Output: TSV format (id, description, type, command, tags, status)
- Example: `filter_all_bookmarks | to_tsv > bookmarks.tsv`

## Real-World Use Cases

### Export Active Bookmarks to CSV

```bash
# Convert active bookmarks to CSV format
filter_all_bookmarks | \
  filter_active | \
  to_tsv | \
  sed 's/\t/,/g' > active_bookmarks.csv
```

### Find Most Used URLs

```bash
# Get top 10 URL bookmarks by frecency
filter_all_bookmarks | \
  filter_by_type "url" | \
  sort_by_frecency | \
  head -10 | \
  format_bookmark_line
```

### List All Scripts with Their Commands

```bash
# Extract script names and commands
filter_all_bookmarks | \
  filter_by_type "script" | \
  jq -r '"\(.description): \(.command)"'
```

### Search for Bookmarks with Multiple Tags

```bash
# Find bookmarks tagged with both "work" and "urgent"
filter_all_bookmarks | \
  filter_by_tag "work" | \
  filter_by_tag "urgent" | \
  format_bookmark_line
```

### Generate Backup of Specific Type

```bash
# Backup only PDF bookmarks
{
  echo '{"bookmarks":['
  filter_all_bookmarks | filter_by_type "pdf" | paste -sd,
  echo ']}'
} > pdf_bookmarks.json
```

### Statistical Analysis

```bash
# Count bookmarks by type
for type in url script pdf note; do
  count=$(filter_all_bookmarks | filter_by_type "$type" | wc -l)
  echo "$type: $count"
done
```

### Integration with Other Tools

```bash
# Send bookmark descriptions to fzf for custom selection
filter_all_bookmarks | \
  filter_by_tag "daily" | \
  extract_field "description" | \
  fzf --prompt="Select bookmark: "

# Use with rofi
filter_all_bookmarks | \
  filter_active | \
  format_bookmark_line | \
  rofi -dmenu -p "Bookmark"

# Grep through bookmarks
filter_all_bookmarks | \
  jq -r '.description + " " + .tags' | \
  grep -i "project"
```

## Pure Functions

Pure functions are functions with no side effects that always return the same output for the same input.

### Examples of Pure Functions

**`detect_system_opener()`**
```bash
# Always returns the same result for the same system state
# No side effects (doesn't modify anything)
opener=$(detect_system_opener)
```

**`calculate_frecency(access_count, last_accessed)`**
```bash
# Same inputs always produce same output
# No global state, no side effects
score=$(calculate_frecency 5 "2025-10-20 10:00:00")
```

**`is_valid_type(type)`**
```bash
# Pure predicate - only checks, doesn't change anything
if is_valid_type "url"; then
  echo "Valid type"
fi
```

### Benefits of Pure Functions

1. **Testable**: Easy to unit test without mocking
2. **Predictable**: No hidden dependencies or side effects
3. **Composable**: Can be combined safely
4. **Parallelizable**: Can be run concurrently without race conditions
5. **Memoizable**: Results can be cached

## Pipeline-Based Data Processing

The refactored `recalculate_all_frecency` function demonstrates pipeline thinking:

### Before (Imperative)

```bash
# Multiple jq calls, building JSON piece by piece
local result='{"bookmarks":[]}'
while read bookmark; do
  access_count=$(echo "$bookmark" | jq '.access_count')
  last_accessed=$(echo "$bookmark" | jq '.last_accessed')
  frecency=$(calculate_frecency "$access_count" "$last_accessed")
  bookmark=$(echo "$bookmark" | jq --argjson score "$frecency" '. + {frecency_score: $score}')
  result=$(echo "$result" | jq --argjson bookmark "$bookmark" '.bookmarks += [$bookmark]')
done
```

Problems:
- Many process spawns (jq called repeatedly)
- Inefficient JSON rebuilding
- Hard to understand data flow
- Difficult to optimize

### After (Pipeline)

```bash
# Extract data -> Transform in awk -> Update JSON
cat "$BOOKMARKS_FILE" | \
  extract_frecency_data | \
  batch_calculate_frecency | \
  # ... update JSON once
```

Benefits:
- Single data flow
- Batch processing
- Easy to understand
- Efficient (fewer process spawns)
- Each stage is independently testable

## Functional Programming Concepts

### Immutability

Prefer creating new data over mutating existing data:

```bash
# Good: Create new JSON, don't modify in place
updated_json=$(jq '.bookmarks += [$entry]' "$BOOKMARKS_FILE")
echo "$updated_json" > "$BOOKMARKS_FILE"

# Not as good: Multiple modifications to same variable
result='{"bookmarks":[]}'
result=$(echo "$result" | jq '.bookmarks += [$entry1]')
result=$(echo "$result" | jq '.bookmarks += [$entry2]')
```

### Function Composition

Build complex operations from simple functions:

```bash
# Compose filters to create complex queries
get_work_urls() {
  filter_all_bookmarks | filter_active | filter_by_type "url" | filter_by_tag "work"
}

# Use the composed function
get_work_urls | format_bookmark_line
```

### Higher-Order Functions

Functions that take or return functions:

```bash
# jq's map is a higher-order function
jq '.bookmarks | map(select(.status == "active"))'

# Creating a filter builder
make_type_filter() {
  local type="$1"
  echo "filter_by_type '$type'"
}

# Use it
eval $(make_type_filter "url") < bookmarks.json
```

## Design Patterns

### The Filter Pattern

```bash
# Every filter follows this pattern:
some_filter() {
  jq -c 'select(CONDITION)'
}

# Filters compose naturally:
filter1 | filter2 | filter3
```

### The Transformer Pattern

```bash
# Transformers map input to different output format:
some_transformer() {
  jq -r 'TRANSFORMATION'
}

# Example: extract and format
extract_field "description" | sed 's/^/- /'
```

### The Pipeline Pattern

```bash
# Complex operations as pipelines:
operation() {
  step1 | step2 | step3 | step4
}

# Each step is independently testable:
echo "$test_data" | step2 | step3
```

## Performance Considerations

### Single-Pass Processing

```bash
# Good: One jq call for multiple operations
jq -r '.bookmarks[] | select(.status == "active") | select(.type == "url") | .description'

# Less good: Multiple jq calls
jq '.bookmarks[]' | jq 'select(.status == "active")' | jq 'select(.type == "url")' | jq '.description'
```

### Batch Operations

```bash
# Good: Batch calculate all frecency scores
extract_frecency_data | batch_calculate_frecency

# Less good: Calculate one at a time in a loop
while read bookmark; do
  calculate_frecency "$access_count" "$last_accessed"
done
```

### Lazy Evaluation

```bash
# Good: Stop processing as soon as we have enough results
filter_all_bookmarks | filter_by_type "url" | head -1

# Less good: Process everything then take one
filter_all_bookmarks | filter_by_type "url" | tail -n 1 | head -1
```

## Testing Pure Functions

Pure functions are easy to test:

```bash
# Test calculate_frecency
test_frecency() {
  result=$(calculate_frecency 10 "2025-10-01 12:00:00")
  expected=12500  # Approximate expected value
  if [ "$result" -gt 12000 ] && [ "$result" -lt 13000 ]; then
    echo "✓ Frecency calculation works"
  fi
}

# Test filter_by_type
test_filter_by_type() {
  result=$(echo '{"type":"url"}' | filter_by_type "url")
  if [ -n "$result" ]; then
    echo "✓ filter_by_type works"
  fi
}
```

## Guidelines for Contributors

When adding new functionality:

1. **Start with a pure function** if possible
2. **Make it a filter** if it processes data
3. **Use pipelines** instead of loops when feasible
4. **Separate concerns**: data access, transformation, presentation
5. **Test in isolation**: each function should be independently testable
6. **Document the interface**: inputs, outputs, side effects

### Example: Adding a New Filter

```bash
# 1. Define the pure filter function
filter_by_created_date() {
  local date="$1"
  jq -c --arg date "$date" 'select(.created | startswith($date))'
}

# 2. Test it independently
echo '{"created":"2025-10-01 10:00:00"}' | filter_by_created_date "2025-10-01"

# 3. Use it in pipelines
filter_all_bookmarks | filter_by_created_date "2025-10" | format_bookmark_line

# 4. Document it
# filter_by_created_date <date>
#   Input: JSON bookmark stream
#   Args: date prefix to match (e.g., "2025-10" or "2025-10-15")
#   Output: Filtered JSON bookmark stream
```

## Further Reading

- [The Art of Unix Programming](http://www.catb.org/~esr/writings/taoup/html/) by Eric S. Raymond
- [Unix Philosophy](https://en.wikipedia.org/wiki/Unix_philosophy) on Wikipedia
- [Functional Programming in Bash](https://www.funtoo.org/Functional_Programming_in_Bash)
- [jq Manual](https://jqlang.github.io/jq/manual/) - Essential for data transformations

## Quotes to Remember

> "Write programs that do one thing and do it well. Write programs to work together. Write programs to handle text streams, because that is a universal interface." 
> — Doug McIlroy

> "Controlling complexity is the essence of computer programming."
> — Brian Kernighan

> "Make it correct, make it clear, make it concise, make it fast. In that order."
> — Wes Dyer

> "The real problem is that programmers have spent far too much time worrying about efficiency in the wrong places and at the wrong times; premature optimization is the root of all evil."
> — Donald Knuth
