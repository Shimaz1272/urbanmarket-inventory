#!/bin/bash
# inventory_manager.sh
# UrbanMarket Supplies Inventory Management Tool
# Authors: [Your Name], [Partner's Name]
# Date: April 23, 2025
# Description: A menu-driven Bash script to manage inventory for UrbanMarket Supplies,
# including viewing, adding, updating, deleting products, recording sales, and generating
# low-stock reports, with data stored in a CSV file.

# File paths
INVENTORY_FILE="inventory.csv"
LOG_FILE="sales.log"
REPORT_FILE="low_stock_report.txt"

# Initialize inventory file if it doesn't exist
initialize_inventory() {
    if [[ ! -f "$INVENTORY_FILE" ]]; then
        echo "ID,Name,Quantity,Price" > "$INVENTORY_FILE"
        echo "Inventory file created: $INVENTORY_FILE"
    fi
}

# Function to display menu
display_menu() {
    echo "=== UrbanMarket Supplies Inventory Manager ==="
    echo "1. View Inventory"
    echo "2. Add New Product"
    echo "3. Update Stock"
    echo "4. Record Sale"
    echo "5. Delete Product"
    echo "6. Low-Stock Report"
    echo "7. Export Low-Stock Report"
    echo "8. Exit"
    read -p "Enter your choice (1-8): " choice
}

# Function to view inventory
view_inventory() {
    if [[ -s "$INVENTORY_FILE" ]]; then
        echo "Current Inventory:"
        column -t -s, "$INVENTORY_FILE"
    else
        echo "Inventory is empty or file is missing."
    fi
}

# Function to add a new product
add_product() {
    read -p "Enter Product ID: " id
    # Validate ID (numeric or alphanumeric, no commas)
    if [[ ! $id =~ ^[a-zA-Z0-9]+$ ]]; then
        echo "Error: ID must be alphanumeric with no spaces or commas."
        return 1
    fi
    # Check if ID exists
    if grep -q "^$id," "$INVENTORY_FILE"; then
        echo "Error: ID $id already exists."
        return 1
    fi
    read -p "Enter Product Name: " name
    # Validate name (no commas)
    if [[ $name == *","* ]]; then
        echo "Error: Name cannot contain commas."
        return 1
    fi
    read -p "Enter Quantity: " quantity
    # Validate quantity (positive integer)
    if [[ ! $quantity =~ ^[0-9]+$ ]]; then
        echo "Error: Quantity must be a positive integer."
        return 1
    fi
    read -p "Enter Price (e.g., 2.50): " price
    # Validate price (positive float or integer)
    if [[ ! $price =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "Error: Price must be a positive number (e.g., 2.50)."
        return 1
    fi
    # Append to CSV
    echo "$id,$name,$quantity,$price" >> "$INVENTORY_FILE"
    echo "Product $name added successfully."
}

# Function to update stock
update_stock() {
    read -p "Enter Product ID or Name: " search
    # Find matching product (case-insensitive for name)
    match=$(grep -i "$search" "$INVENTORY_FILE")
    if [[ -z "$match" ]]; then
        echo "Error: Product not found."
        return 1
    fi
    # If multiple matches, show them and ask for ID
    if [[ $(echo "$match" | wc -l) -gt 1 ]]; then
        echo "Multiple matches found:"
        echo "$match" | awk -F, '{print "ID: " $1 ", Name: " $2 ", Qty: " $3 ", Price: " $4}'
        read -p "Enter the exact Product ID: " search
        match=$(grep "^$search," "$INVENTORY_FILE")
        if [[ -z "$match" ]]; then
            echo "Error: Invalid ID."
            return 1
        fi
    fi
    # Extract current quantity
    current_qty=$(echo "$match" | cut -d, -f3)
    echo "Found: $match"
    read -p "Enter quantity to add/subtract (use - for subtract, e.g., -5 or 10): " change
    # Validate change (integer, positive or negative)
    if [[ ! $change =~ ^-?[0-9]+$ ]]; then
        echo "Error: Change must be an integer (e.g., -5 or 10)."
        return 1
    fi
    # Calculate new quantity
    new_qty=$((current_qty + change))
    if [[ $new_qty -lt 0 ]]; then
        echo "Error: New quantity cannot be negative."
        return 1
    fi
    # Update CSV (replace line)
    awk -F, -v id="$search" -v qty="$new_qty" \
        '$1 == id {$3 = qty} {print $1 "," $2 "," $3 "," $4}' "$INVENTORY_FILE" > temp.csv
    mv temp.csv "$INVENTORY_FILE"
    echo "Stock updated successfully: New quantity is $new_qty."
}

# Function to record sale
record_sale() {
    read -p "Enter Product ID or Name: " search
    # Find matching product
    match=$(grep -i "$search" "$INVENTORY_FILE")
    if [[ -z "$match" ]]; then
        echo "Error: Product not found."
        return 1
    fi
    # Handle multiple matches
    if [[ $(echo "$match" | wc -l) -gt 1 ]]; then
        echo "Multiple matches found:"
        echo "$match" | awk -F, '{print "ID: " $1 ", Name: " $2 ", Qty: " $3 ", Price: " $4}'
        read -p "Enter the exact Product ID: " search
        match=$(grep "^$search," "$INVENTORY_FILE")
        if [[ -z "$match" ]]; then
            echo "Error: Invalid ID."
            return 1
        fi
    fi
    # Extract current quantity and name
    current_qty=$(echo "$match" | cut -d, -f3)
    name=$(echo "$match" | cut -d, -f2)
    read -p "Enter Quantity Sold: " sold
    # Validate sold (positive integer)
    if [[ ! $sold =~ ^[0-9]+$ ]]; then
        echo "Error: Quantity sold must be a positive integer."
        return 1
    fi
    # Check if enough stock
    if [[ $sold -gt $current_qty ]]; then
        echo "Error: Not enough stock (current: $current_qty)."
        return 1
    fi
    # Update quantity
    new_qty=$((current_qty - sold))
    awk -F, -v id="$search" -v qty="$new_qty" \
        '$1 == id {$3 = qty} {print $1 "," $2 "," $3 "," $4}' "$INVENTORY_FILE" > temp.csv
    mv temp.csv "$INVENTORY_FILE"
    # Log sale
    echo "$(date): Sold $sold of $name (ID: $search)" >> "$LOG_FILE"
    echo "Sale recorded: $sold units of $name."
}

# Function to delete product
delete_product() {
    read -p "Enter Product ID or Name: " search
    # Find matching product
    match=$(grep -i "$search" "$INVENTORY_FILE")
    if [[ -z "$match" ]]; then
        echo "Error: Product not found."
        return 1
    fi
    # Handle multiple matches
    if [[ $(echo "$match" | wc -l) -gt 1 ]]; then
        echo "Multiple matches found:"
        echo "$match" | awk -F, '{print "ID: " $1 ", Name: " $2 ", Qty: " $3 ", Price: " $4}'
        read -p "Enter the exact Product ID: " search
        match=$(grep "^$search," "$INVENTORY_FILE")
        if [[ -z "$match" ]]; then
            echo "Error: Invalid ID."
            return 1
        fi
    fi
    # Delete product (remove line)
    grep -v "^$search," "$INVENTORY_FILE" > temp.csv
    mv temp.csv "$INVENTORY_FILE"
    echo "Product deleted successfully."
}

# Function to generate low-stock report
low_stock_report() {
    threshold=5
    echo "Low-Stock Report (Quantity <= $threshold):"
    report=$(awk -F, -v thresh="$threshold" \
        '$3 <= thresh && NR > 1 {print $2 " (ID: " $1 ", Qty: " $3 ", Price: " $4 ")"}' "$INVENTORY_FILE")
    if [[ -z "$report" ]]; then
        echo "No items are low on stock."
    else
        echo "$report"
    fi
}

# Function to export low-stock report
export_report() {
    threshold=5
    echo "Exporting Low-Stock Report to $REPORT_FILE..."
    echo "Low-Stock Report (Quantity <= $threshold) - $(date)" > "$REPORT_FILE"
    awk -F, -v thresh="$threshold" \
        '$3 <= thresh && NR > 1 {print $2 " (ID: " $1 ", Qty: " $3 ", Price: " $4 ")"}' "$INVENTORY_FILE" >> "$REPORT_FILE"
    if [[ $? -eq 0 ]]; then
        echo "Report exported successfully to $REPORT_FILE."
    else
        echo "Error: Failed to export report."
    fi
}

# Main loop
initialize_inventory
while true; do
    display_menu
    case "$choice" in
        1) view_inventory ;;
        2) add_product ;;
        3) update_stock ;;
        4) record_sale ;;
        5) delete_product ;;
        6) low_stock_report ;;
        7) export_report ;;
        8) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid choice. Try again." ;;
    esac
    read -p "Press Enter to continue..."
done
