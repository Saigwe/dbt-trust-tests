{#- A boolean SQL expression: does `expr` match the regular expression `pattern`? One call site per dialect. -#}
{% macro regex_matches(expr, pattern) -%}
    {{ return(adapter.dispatch('regex_matches', 'trust_tests')(expr, pattern)) }}
{%- endmacro %}

{% macro default__regex_matches(expr, pattern) -%}
    regexp_like({{ expr }}, '{{ pattern }}')
{%- endmacro %}

{% macro duckdb__regex_matches(expr, pattern) -%}
    regexp_full_match({{ expr }}, '{{ pattern }}')
{%- endmacro %}

{% macro postgres__regex_matches(expr, pattern) -%}
    ({{ expr }} ~ '^(?:{{ pattern }})$')
{%- endmacro %}

{% macro snowflake__regex_matches(expr, pattern) -%}
    regexp_like({{ expr }}, '{{ pattern }}')
{%- endmacro %}

{% macro bigquery__regex_matches(expr, pattern) -%}
    regexp_contains({{ expr }}, r'^(?:{{ pattern }})$')
{%- endmacro %}
