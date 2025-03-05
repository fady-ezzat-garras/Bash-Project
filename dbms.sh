#!/bin/bash

mainMenu() {
    while true
    do
        echo "Main Menu:"
        select choice in "Create Database" "List Databases" "Drop Database" "Connect to Database" "Exit"
         do
            case $REPLY in
                1) createDB 
                2) listDB 
                3) dropDB 
                4) connectDB 
                5) exit 0 
                *) echo "Invalid choice" 
            esac
            break
        done
    done
}

createDB() {
    while true
	 do
        echo "____________________________________________"
        read -p "Enter database name (or exit): " DBname
        
        if [[ $DBname == "exit" ]]
 	 then return
	 fi
        
        if [ -z "$DBname" ]
	 then
            echo "Name can't be empty!"
        elif [[ ! $DBname =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]
	 then
            echo "Invalid name! Use letters/numbers/underscores"
        elif [ -d "Databases/$DBname" ]
	 then
            echo "Database exists!"
        else
            mkdir -p "Databases/$DBname"
            echo "Database $DBname created!"
            return
        fi
    done
}

listDB() {
    echo "Databases:"
    ls -1 Databases 2>/dev/null || echo "No databases found"
}

dropDB() {
    while true
	 do
        read -p "Enter database to delete (or exit): " DBname
        if [[ $DBname == "exit" ]]
	 then
	 return
	 fi
        
        if [ -d "Databases/$DBname" ]
	then
            rm -r "Databases/$DBname" && echo "Deleted!" || echo "Error!"
            return
        else
            echo "Not found!"
        fi
    done
}

connectDB() {
    while true
	 do
        read -p "Enter database name (or exit): " DBname
        if [[ $DBname == "exit" ]]
	 then
	 return
	 fi
        
        if [ -d "Databases/$DBname" ]
	 then
            cd "Databases/$DBname"
            tableMenu
            cd ../..
            return
        else
            echo "Database doesn't exist!"
        fi
    done
}

tableMenu() {
    while true
	do
        echo "Table Menu:"
        select choice in "Create Table" "List Tables" "Drop Table" "Insert" "View" "Delete" "Update" "Exit"
	do
            case $REPLY in
                1) createTable 
                2) listTables 
                3) dropTable 
                4) insertData 
                5) viewData 
                6) deleteData 
                7) updateData 
                8) return 
                *) echo "Invalid choice" 
            esac
            break
        done
    done
}

createTable() {
    while true
	do
        read -p "Enter table name (or exit): " tblName
        if [[ $tblName == "exit" ]]
	 then
	 return
	fi
        
        if [ -f "$tblName" ]
	 then
            echo "Table exists!"
        elif [[ ! $tblName =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]
	 then
            echo "Invalid name!"
        else
            # Create metadata file
            touch ".$tblName.meta"
            
            # Get columns info
            while true
		 do
                read -p "Number of columns (1-10): " cols
                [[ $cols =~ ^[1-9]$|^10$ ]] && break
                echo "Invalid number!"
            done
            
            pkSet=0
            for ((i=1;i<=cols;i++))
		 do
                while true
		 do
                    read -p "Column $i name: " colName
                    [[ $colName =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]] && break
                    echo "Invalid name!"
                done
                
                # Data type
                while true
		 do
                    read -p "Data type (str/int): " dtype
                    [[ $dtype == "str" || $dtype == "int" ]] && break
                    echo "Invalid type!"
                done
                
                # Primary key
                pk=""
                if (( pkSet == 0 ))
			 then
                    read -p "Make PK? (y/n): " pkChoice
                    [[ $pkChoice == "y" ]] && { pk=":pk"; pkSet=1; }
                fi
                
                echo "$colName:$dtype$pk" >> ".$tblName.meta"
            done
            
            touch "$tblName"
            echo "Table $tblName created!"
            return
        fi
    done
}

insertData() {
    while true
	do
        read -p "Enter table name (or exit): " tblName
        [[ $tblName == "exit" ]] && return
        
        if [ ! -f "$tblName" ]
	 then
            echo "Table doesn't exist!"
            continue
        fi
        
        # Read metadata
        meta=()
        while IFS= read -r line
	 do
            meta+=("$line")
        done < ".$tblName.meta"
        
        # Build row
        row=""
        for col in "${meta[@]}"
	 do
            IFS=':' read -r name dtype pk <<< "$col"
            while true
		 do
                read -p "$name ($dtype): " value
                
                # Check PK
                if [[ $pk == "pk" ]]
		then
                    if cut -d'|' -f1 "$tblName" | grep -q "^$value$"
		 then
                        echo "PK exists!"
                        continue
                    fi
                fi
                
                # Check data type
                if [[ $dtype == "int" && ! $value =~ ^[0-9]+$ ]]
		 then
                    echo "Numbers only!"
                else
                    row+="$value|"
                    break
                fi
            done
        done
        
        # Save row
        echo "${row%|}" >> "$tblName"
        echo "Data inserted!"
        return
    done
}

viewData() {
    read -p "Enter table name: " tblName
    [ ! -f "$tblName" ] && { echo "Table doesn't exist!"
	 return
	   }
    
    echo "Data:"
    echo "------------------------"
    tr '|' '\t' < "$tblName"
    echo "------------------------"
}

deleteData() {
    read -p "Enter table name: " tblName
    [ ! -f "$tblName" ] && { echo "Table doesn't exist!"
	 return
	    }
    
    read -p "Enter PK value: " pkVal
    
    temp=$(mktemp)
    found=0
    while IFS= read -r line
	 do
        currentPK=$(echo "$line" | cut -d'|' -f1)
        if [[ $currentPK == "$pkVal" ]]
	 then
            found=1
            continue
        fi
        echo "$line" >> "$temp"
    done < "$tblName"
    
    if (( found == 1 )); then
        mv "$temp" "$tblName"
        echo "Deleted!"
    else
        echo "PK not found!"
        rm "$temp"
    fi
}

updateData() {
    read -p "Enter table name: " tblName
    [ ! -f "$tblName" ] && { echo "Table doesn't exist!"
	 return
		 }
    
    # Read metadata
    meta=()
    while IFS= read -r line
	 do
        meta+=("$line")
    done < ".$tblName.meta"
    
    # Get PK
    read -p "Enter PK value: " pkVal
    
    # Find row
    row=""
    while IFS= read -r line
	 do
        currentPK=$(echo "$line" | cut -d'|' -f1)
        [[ $currentPK == "$pkVal" ]] && row="$line" && break
    done < "$tblName"
    
    [ -z "$row" ] && { echo "PK not found!"
	 return
	 }
    
    # Show columns
    echo "Select column:"
    for ((i=1;i<${#meta[@]};i++))
	do
        echo "$i) $(echo "${meta[$i]}" | cut -d':' -f1)"
    done
    
    # Get column choice
    while true
	 do
        read -p "Column number: " colNum
        (( colNum >= 1 && colNum < ${#meta[@]} )) && break
        echo "Invalid number!"
    done
    
    # Get new value
    IFS=':' read -r name dtype pk <<< "${meta[$colNum]}"
    while true
	 do
        read -p "New value ($dtype): " newVal
        [[ $dtype == "int" && ! $newVal =~ ^[0-9]+$ ]] && { echo "Numbers only!"
	 continue
	 }
        break
    done
    
    # Update row
    temp=$(mktemp)
    while IFS= read -r line
	 do
        if [[ $line == "$row" ]]
	 then
            IFS='|' read -ra fields <<< "$line"
            fields[$colNum]="$newVal"
            newRow=$(IFS='|'; echo "${fields[*]}")
            echo "$newRow"
        else
            echo "$line"
        fi
    done < "$tblName" > "$temp"
    
    mv "$temp" "$tblName"
    echo "Updated!"
}

listTables() {
    echo "Tables:"
    ls -1 | grep -v '\.meta$' 2>/dev/null || echo "No tables found"
}

dropTable() {
    read -p "Enter table to delete: " tblName
    [ ! -f "$tblName" ] && { echo "Not found!"
	 return
	 }
    rm -f "$tblName" ".$tblName.meta" && echo "Deleted!" || echo "Error!"
}

# Start program
mainMenu
