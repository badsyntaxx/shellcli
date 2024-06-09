# Sample array and hashtable
$array = "first", "third", "fifth"
$hashtable = [ordered]@{
    "first"  = 1
    "second" = 2
    "third"  = 3
    "fourth" = 4
    "fifth"  = 5
}

# Create a new hashtable to store the filtered key-value pairs
$filteredHashtable = @{}

# Iterate through the keys in the hashtable
foreach ($key in $hashtable.Keys) {
    if ($array -contains $key) {
        # Add the key-value pair to the filtered hashtable
        $filteredHashtable[$key] = $hashtable[$key]
    }
}

# Display the filtered hashtable
$filteredHashtable
