strip_nulls() {
  jq 'walk(
    if type == "object"
    then with_entries(select(.value != null))
    else .
    end
  )'
}
