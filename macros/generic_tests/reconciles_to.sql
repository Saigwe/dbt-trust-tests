{#-
  Totals tie out: for every group, each measure in the model equals the same measure in another relation (a source,
  an upstream model, a ledger), within an absolute tolerance. A group present on only one side fails too.

    tests:
      - trust_tests.reconciles_to:
          arguments:
            to: source('bronze', 'claims')
            measures: {n_rows: "count(*)", paid: "sum(paid_usd)"}
            to_measures: {paid: "sum(cast(clm_pmt_amt as numeric(14, 2)))"}   # optional, when the expression differs
            group_by: [setting]                                                # optional
            tolerance: 0.01                                                    # optional, default 0
            where: "not is_test"                                               # optional filters, either side
            to_where: "load_status = 'ok'"

  Each failing row names the group, the measure, and both values.
-#}
{% test reconciles_to(model, to, measures, group_by=[], tolerance=0, to_measures={}, where=none, to_where=none) %}
{%- set keys = group_by if group_by else [] -%}
{%- set key_list = keys | join(', ') -%}
with model_side as (
    select
        {% for k in keys %}{{ k }}, {% endfor %}
        {% for name, expr in measures.items() %}{{ expr }} as {{ name }}{{ "," if not loop.last }}{% endfor %}
    from {{ model }}
    {% if where %}where {{ where }}{% endif %}
    {% if keys %}group by {{ key_list }}{% endif %}
),

to_side as (
    select
        {% for k in keys %}{{ k }}, {% endfor %}
        {% for name, expr in measures.items() %}{{ to_measures.get(name, expr) }} as {{ name }}{{ "," if not loop.last }}{% endfor %}
    from {{ to }}
    {% if to_where %}where {{ to_where }}{% endif %}
    {% if keys %}group by {{ key_list }}{% endif %}
),

compared as (
    {% for name in measures.keys() %}
    select
        {% for k in keys %}coalesce(m.{{ k }}, t.{{ k }}) as {{ k }}, {% endfor %}
        '{{ name }}' as measure,
        cast(m.{{ name }} as {{ dbt.type_numeric() }}) as model_value,
        cast(t.{{ name }} as {{ dbt.type_numeric() }}) as to_value,
        (m.{{ name }} is null) <> (t.{{ name }} is null) as missing_one_side
    from model_side m
    full outer join to_side t
        {% if keys %}on {% for k in keys %}m.{{ k }} = t.{{ k }}{{ " and " if not loop.last }}{% endfor %}{% else %}on 1 = 1{% endif %}
    {{ "union all" if not loop.last }}
    {% endfor %}
)

select *
from compared
where missing_one_side
   or abs(coalesce(model_value, 0) - coalesce(to_value, 0)) > {{ tolerance }}
{% endtest %}
