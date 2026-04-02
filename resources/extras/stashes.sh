dump_stashes() {
  local start=$1
  local end=$2
  local outfile=${3:-"stash_dump.txt"} # Defaults to stash_dump.txt if no name is provided

  if [[ -z "$start" || -z "$end" ]]; then
    echo "Usage: dump_stashes <start_index> <end_index> [output_file.txt]"
    return 1
  fi

  echo "Dumping stashes $start through $end to $outfile..."
  
  # Clear the file if it exists, or create a new one
  > "$outfile"

  for (( i=start; i<=end; i++ )); do
    echo "========================================" >> "$outfile"
    echo " STASH @{$i}" >> "$outfile"
    echo "========================================" >> "$outfile"
    
    # Using -p to get the actual patch/diff content
    git stash show -p "stash@{$i}" >> "$outfile"
    
    # Add some spacing between entries
    echo -e "\n\n" >> "$outfile"
  done

  echo "Done! Output saved to $outfile"
}
echo done;

dump_stashes_files() {
  local start=$1
  local end=$2
  local outfile=${3:-"stash_dump.txt"} # Defaults to stash_dump.txt if no name is provided

  if [[ -z "$start" || -z "$end" ]]; then
    echo "Usage: dump_stashes <start_index> <end_index> [output_file.txt]"
    return 1
  fi

  echo "Dumping stashes $start through $end to $outfile..."
  
  # Clear the file if it exists, or create a new one
  > "$outfile"

  for (( i=start; i<=end; i++ )); do
    echo "========================================" >> "$outfile"
    echo " STASH @{$i}" >> "$outfile"
    echo "========================================" >> "$outfile"
    
    # Using -p to get the actual patch/diff content
    git stash show "stash@{$i}" >> "$outfile"
    
    # Add some spacing between entries
    echo -e "\n\n" >> "$outfile"
  done

  echo "Done! Output saved to $outfile"
}
echo done
