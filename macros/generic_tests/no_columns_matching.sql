{#-
  A column-name policy: the model must not have any column whose name matches one of the patterns (case-insensitive,
  whole-name regular expressions). Use it to keep raw identifiers and personal data out of silver and gold.

    tests:
      - trust_tests.no_columns_matching:
          arguments:
            patterns: ['.*birth_?(dt|date).*', 'member_id', '.*npi', 'email.*']

  Each failing row names one offending column. The check reads the relation's columns from the warehouse at test time,
  so it also catches columns added outside the YAML.
-#}
{% test no_columns_matching(model, patterns) %}
{%- set offending = [] -%}
{%- if execute -%}
    {%- for col in adapter.get_columns_in_relation(model) -%}
        {%- for p in patterns -%}
            {%- if modules.re.fullmatch(p, col.name, modules.re.IGNORECASE) and col.name not in offending -%}
                {%- do offending.append(col.name) -%}
            {%- endif -%}
        {%- endfor -%}
    {%- endfor -%}
{%- endif -%}
{% if offending %}
    {% for c in offending %}
select '{{ c }}' as offending_column{{ " union all" if not loop.last }}
    {% endfor %}
{% else %}
select cast(null as {{ dbt.type_string() }}) as offending_column where 1 = 0
{% endif %}
{% endtest %}
