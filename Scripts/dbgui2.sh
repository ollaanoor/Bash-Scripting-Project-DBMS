#!/usr/bin/bash
dbname=$1
datatypes=('integer' 'float' 'string')
declare -A values # associative array/dictionary to hold the input values for insert and update fns

create_table() {
	col=""
	dt=""
	tablename=$(zenity --entry --title="Create Table" --text="Enter table name:")
	if [[ $? == 0 ]]; then
		if [[ -n $tablename ]]; then
			if [[ -e ~/myDB/$dbname/$tablename ]]; then
				zenity --error --title="Error" --text="Table already exists."
			else
				flag=0
				while [[ $flag == 0 ]]; do
					# take number of fields from user
					num_fields=$(zenity --entry --title="Setting Number of Fields" --text="Enter number of fields:")
					
					# check if user clicked Cancel
					if [[ $? -eq 1 ]]; then
						zenity --question --title="Warning" --text="Table will not be created. Are you sure you want to cancel?" --ok-label="Yes" --cancel-label="No"
						if [[ $? == 0 ]]; then
							return;
						fi
					else 
						# check if user clicked OK without entering number of fields
						if [[ -z $num_fields ]]; then
							zenity --error --title="Error" --text="Must specify number of fields."
						else 
							flag=1
						fi
					fi
				done

				# take field names and data types from user
				flag=0
				count=0
			    while [[ $count -lt $num_fields ]]; do

	  				field_data=$(zenity --forms --title="Setting Fields" \
	  					--text="Enter field name and select data type:" \
	  					--add-entry="Field name" \
	  					--add-combo="Field data type" \
	  					--combo-values="integer|string|float")
	  						
	  				# Check if the user clicked OK
	  				if [[ $? -eq 0 ]]; then
						
						# Split the field_data into two variables
						fieldname=$(echo $field_data | awk -F'|' '{print $1}')
						dtype=$(echo $field_data | awk -F'|' '{print $2}')

						if [[ -z $fieldname ]]; then
							zenity --error --title="Error" --text="Field data cannot be empty."
							continue;
						fi

				    	fieldname=`echo $fieldname | tr [A-Z] [a-z]`

						# check if col name is unique
						for i in $col; do
							if [[ $fieldname == $i ]]; then
								zenity --error --title="Error" --text="Field already exists."
					    		continue 2; 
					    	fi
				    	done

						col="$col $fieldname"
						dt="$dt $dtype"
				    	
				    	((count++))
				    else
						zenity --question --title="Warning" --text="Table will not be created. Are you sure you want to cancel?" --ok-label="Yes" --cancel-label="No"
						if [[ $? == 1 ]]; then
							flag=1;
							break;
						fi
					fi
			    done

			    while [[ $flag == 0 ]]; do
				    options=$(echo $col | tr ' ' '|')
					PK=$(zenity --forms --title="Primary Key" \
		  				--text="                        Select field to set as Primary Key                        " \
						--add-combo="                                          " \
		  				--combo-values="$options")
		  			if [[ $? == 0 ]]; then
					    PK=`echo "$PK" | tr [A-Z] [a-z]`
					    count=1
					    for c in $col; do
					    	if [[ "$PK" == "$c" ]]; then
					    		break;
					    	fi
					    	((count++))
					    done
					    flag=1 # table creation successful
					else 
						zenity --question --title="Warning" --text="Table will not be created. Are you sure you want to cancel?" --ok-label="Yes" --cancel-label="No"
						if [[ $? == 0 ]]; then # user clicked Yes
							break;
						else
							flag=0
						fi
					fi
				done
				if [[ $flag == 1 ]]; then
					touch ~/myDB/$dbname/$tablename 2>/dev/null
					echo "${dt## }" >> ~/myDB/$dbname/$tablename
					echo "${col## }" >> ~/myDB/$dbname/$tablename
					echo "$count:$PK" >> ~/myDB/$dbname/$tablename # index of field that is PK_index:PK_field

					zenity --info --title="Success" --text="Table '$tablename' created successfully."
				fi
			fi
		else
			zenity --error --title="Error" --text="Table name cannot be empty."
		fi
	fi
}

list_tables() {
	if [[ -n $(ls -A ~/myDB/$dbname) ]]; then
		data=$(ls ~/myDB/$dbname)
		zenity --text-info --title="Existing Tables" --filename=<(echo "$data")
	else 
	    zenity --error --title="Error" --text="No Tables found."
	fi
}

drop_table() {
	options=$(ls ~/myDB/$dbname | tr '\n' '|' | rev | cut -d'|' -f2- | rev)
	tablename=$(zenity --forms --title="DROP Table" \
	  	--text="                        Select table to drop                        " \
	    --add-combo="                              " \
	  	--combo-values="$options")
	if [[ $? == 0 ]]; then
		if [[ -n $tablename ]]; then
			#if [[ -e ~/myDB/$dbname/$tablename ]]; then
			    rm ~/myDB/$dbname/$tablename
			    zenity --info --title="Success" --text="Table '$tablename' deleted successfully."
			#else 
			#    zenity --error --title="Error" --text="Table does not exist."
			#fi
		else
			zenity --error --title="Error" --text="Table name cannot be empty."
		fi
	fi
}

insert_into_table() {
	record="" # to hold data in correct order to insert to file
	options=$(ls ~/myDB/$dbname | tr '\n' '|' | rev | cut -d'|' -f2- | rev)
	tablename=$(zenity --forms --title="INSERT INTO Table" \
	  	--text="                        Select table to insert into                        " \
	    --add-combo="                                " \
	  	--combo-values="$options")
	if [[ $? == 0 ]]; then
		if [[ -n $tablename ]]; then
			# check that tables exists
			if [[ -e ~/myDB/$dbname/$tablename ]]; then
				# fetch the 1st line from file that contains the data types
				dt=`sed -n '1p' ~/myDB/$dbname/$tablename`
				# fetch the 2nd line from file that contains the field names
				col=`sed -n '2p' ~/myDB/$dbname/$tablename`
				# fetch the 3rd line that contains PK of table PKidx:PKfield
				PK=`sed -n '3p' ~/myDB/$dbname/$tablename`
				PKidx=`echo "$PK" | cut -d: -f1`
				PKfield=`echo "$PK" | cut -d: -f2`
				
				ins=0 # insert flag to keep dialog open until user enters correct data
				while(( $ins == 0 )); do
				
				# clear values array
				for key in "${!values[@]}"; do
	    			unset values[$key]
				done

				# read data from user in the format: field=value field=value
				command=$(zenity --entry --title="INSERT" --text="field=value:")
				
				# check if user clicked cancel
				if [[ $? == 1 ]]; then
					break;
				fi

				if [[ -z $command ]]; then
					zenity --error --title="Error" --text="Must specify fields."
					continue;
				fi

				# check cols given by user matches available cols
				for c in $command; do
					# key holds field name taken from user
				    key=`echo $c | cut -d= -f1 | tr [A-Z] [a-z]` 
					idx=0 # index of current field in table(file)
					inv=0 # invalid flag
					# checking if field name entered by user exists in table
					for k in $col; do
						if [[ $key != $k ]];then
							inv=1
						elif [[ $key == $k ]];then
							inv=0
							break;
						fi
						if [[ $inv -eq 1 && $k == ${col##* } ]];then 
							zenity --error --title="Error" --text="Invalid field name '$key'."
							#break 2;
							continue 2;
						fi
						((idx++)) # index of field in table to be used to get datatype
					done
					value=`echo $c | cut -d= -f2` # value holds data taken from user 
					count=0 # count to be used in for loop to get datatype of field
					for d in $dt; do
						if [[ $count == $idx ]];then
							datype=$d # datype holds datatype of field
							break;
						fi
						((count++))
					done
					# check if value entered by user matches datatype of field
					case $datype in
						"integer")
							if [[ "$value" =~ ^[0-9]+$ ]];then
								values[$key]="$value"
							else
								zenity --error --title="Error" --text="Invalid datatype."
								inv=1
								break;
							fi
				    	;;
						"string")
							if [[ "$value" =~ ^[a-zA-Z]+$ ]];then
								values[$key]="$value"
							else
								zenity --error --title="Error" --text="Invalid datatype."
								inv=1
								break;
							fi
						;;
						"float")
							if [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]];then
								values[$key]="$value"
							else
								zenity --error --title="Error" --text="Invalid datatype."
			    				inv=1
			    				break;
			    			fi
			    		;;
				    esac
				done

				# if all fields are valid then insert record
				if [[ $inv == 0 ]]; then
				    flag=0
					for field in $col;do
					    if [[ -n $record ]]; then # if record not empty add colon
							record+=":"
						fi
						if [[ -z ${values[$field]} && $PKfield == $field ]]; then
							flag=1
							zenity --error --title="Error" --text="$field is a Primary key. Cannot be NULL."
							break;
						fi
						if [[ -n ${values[$field]} && $PKfield == $field ]]; then
							unique=$(awk -F: -v PKidx=$PKidx -v value=${values[$field]} 'NR > 3 {if($PKidx==value){print -1}}' ~/myDB/$dbname/$tablename)
							if [[ $unique == -1 ]]; then
								flag=1
								zenity --error --title="Error" --text="$field is a Primary key. MUST be UNIQUE."
								break;
							fi
						fi
						record+="${values[$field]}"
					done
					if [[ $flag == 0 ]]; then
						echo $record >> ~/myDB/$dbname/$tablename
						zenity --info --title="Success" --text="Record was inserted successfully."
						ins=1;
					fi
				fi
				done
			else
				zenity --error --title="Error" --text="Table does not exist."
			fi
		else
			zenity --error --title="Error" --text="Table name cannot be empty."
		fi
	fi
}

select_from_table() {
	idx=1
	options=$(ls ~/myDB/$dbname | tr '\n' '|' | rev | cut -d'|' -f2- | rev)
	tablename=$(zenity --forms --title="SELECT FROM Table" \
	  	--text="                        Choose table to select from                        " \
	    --add-combo="                                " \
	  	--combo-values="$options")
	if [[ $? == 0 ]]; then
		if [[ -n $tablename ]]; then
			# check that tables exists
			#if [[ -e ~/myDB/$dbname/$tablename ]]; then
			# existing fields in table
			col=`sed -n '2p' ~/myDB/$dbname/$tablename` 
			flag=0
			while [[ $flag == 0 ]]; do
				# fields user want to display input format-> name=Olla
				condition=$(zenity --entry --title="WHERE Condition" --text="Where 'field=value':") 
				if [[ $? == 0 ]]; then
					if [[ -n $condition ]]; then
						field=`echo $condition | cut -d= -f1 | tr [A-Z] [a-z]`
						value=`echo $condition | cut -d= -f2`
						
						# check if field name entered by user exists in table
						for f in $col; do 
							if [[ $field == $f ]]; then 
								if [[ -n $value ]]; then # select records with specific field value
									data=$(awk -F: -v idx=$idx -v value=$value 'NR > 3 && $idx == value {OFS=" "; $1=$1; print $0}' ~/myDB/$dbname/$tablename)
									zenity --text-info --title="Selected Records" --filename=<(echo "$col" && echo "$data")
								else # select with field only, all records but only display selected field
									data=$(awk -F: -v idx=$idx 'NR > 3 {print $idx}' ~/myDB/$dbname/$tablename)
									zenity --text-info --title="Selected Fields" --filename=<(echo "$field" && echo "$data")
								fi
								flag=1
								break;
							elif [[ $field != $f && $f == ${col##* } ]]; then
								zenity --error --title="Error" --text="Field does not exist." 
								return;
							fi
							((idx++))
						done
					else
						zenity --error --title="Error" --text="Must specify condition."
					fi
				else
					break;
				fi
			done
			#else
			#	zenity --error --title="Error" --text="Table does not exist."
			#fi
		else
			zenity --error --title="Error" --text="Table name cannot be empty."
		fi
	fi
}

delete_from_table() {
	idx=1
	options=$(ls ~/myDB/$dbname | tr '\n' '|' | rev | cut -d'|' -f2- | rev)
	tablename=$(zenity --forms --title="DELETE FROM Table" \
	  	--text="                        Select table to delete from                        " \
	    --add-combo="                                " \
	  	--combo-values="$options")
	if [[ $? == 0 ]]; then
		if [[ -n $tablename ]]; then
			# check that tables exists
			#if [[ -e ~/myDB/$dbname/$tablename ]]; then
			# existing fields in table
			col=`sed -n '2p' ~/myDB/$dbname/$tablename` 
			flag=0
			while [[ $flag == 0 ]]; do
				# fields user want to display input format-> name=Olla
				condition=$(zenity --entry --title="WHERE Condition" --text="Where 'field=value':") 
				if [[ $? == 0 ]]; then
					if [[ -n $condition ]]; then
						field=`echo $condition | cut -d= -f1 | tr [A-Z] [a-z]`
						value=`echo $condition | cut -d= -f2`
					
						# check if field name entered by user exists in table
						for f in $col; do 
							if [[ $field == $f ]]; then 
								if [[ -n $value ]]; then
									valexists=$(awk -F: -v idx=$idx -v value=$value 'NR > 3 {if($idx==value){print 1}}' ~/myDB/$dbname/$tablename)
									if [[ $valexists != 1 ]]; then
										zenity --error --title="Error" --text="Record does not exist."
										break 2;
									fi
									# get the line numbers of records to be deleted
									data=$(awk -F: -v idx=$idx -v value=$value 'NR > 3 {if($idx==value){print NR}}' ~/myDB/$dbname/$tablename) 
									# convert $del to new-line separated values and sort them in reverse
									data=`echo $data | tr ' ' '\n' | sort -r` 
									# delete records from file
									for d in $data; do
										sed -i "${d}d" ~/myDB/$dbname/$tablename
									done
									zenity --info --title="Success" --text="Records where '$condition' are deleted successfully."
									flag=1
								else
									zenity --error --title="Error" --text="Must specify value."	
								fi
								break;
							elif [[ $field != $f && $f == ${col##* } ]]; then
								zenity --error --title="Error" --text="Field does not exist." 
								return;
							fi
							((idx++))
						done
					else
						zenity --error --title="Error" --text="Must specify condition."
					fi
				else
					break;
				fi
			done
			#else
			#	zenity --error --title="Error" --text="Table does not exist."
			#fi
		else
			zenity --error --title="Error" --text="Table name cannot be empty."
		fi
	fi
}

update_table() {
	idx=1
	unique=0
	options=$(ls ~/myDB/$dbname | tr '\n' '|' | rev | cut -d'|' -f2- | rev)
	tablename=$(zenity --forms --title="UPDATE Table" \
	  	--text="                        Select table to update in                        " \
	    --add-combo="                                " \
	  	--combo-values="$options")
	if [[ $? == 0 ]]; then
		if [[ -n $tablename ]]; then
			# check that tables exists
			#if [[ -e ~/myDB/$dbname/$tablename ]]; then
			
				# fetch the 1st line from file that contains the data types
				dt=`sed -n '1p' ~/myDB/$dbname/$tablename`
				# existing fields in table
				col=`sed -n '2p' ~/myDB/$dbname/$tablename` 
				# 3rd line contains PK of table
				PK=`sed -n '3p' ~/myDB/$dbname/$tablename`
				PKidx=`echo $PK | cut -d: -f1`
				PKfield=`echo $PK | cut -d: -f2`
				
				while true; do
				# Take field that user wants to update and new value
				result=$(zenity --forms \
					--title="UPDATE Table" \
					--text="Enter condition:" \
					--add-combo="Where field" \
					--combo-values=$(echo $col | tr ' ' '|') \
					--add-entry="Value" \
					--add-combo="Update field" \
					--combo-values=$(echo $col | tr ' ' '|') \
					--add-entry="New value")
					
				if [[ $? == 0 ]]; then
					rid=$(echo $result | cut -d'|' -f1)
					val=$(echo $result | cut -d'|' -f2)
					fname=$(echo $result | cut -d'|' -f3)
					newval=$(echo $result | cut -d'|' -f4)
					if [[ -z $rid || -z $val || -z $fname || -z $newval ]]; then # this also makes sure that if field is PK then it will not be NULL
						zenity --error --title="Error" --text="All fields are required."
						continue;
					else
						ridx=1
						for c in $col; do
							if [[ $rid == $c ]]; then
								break;
							fi
   							((ridx++))
						done

						valexists=$(awk -F: -v ridx=$ridx -v val=$val 'NR > 3 {if($ridx==val){print 1}}' ~/myDB/$dbname/$tablename)
			    		if [[ $valexists != 1 ]]; then
			    			zenity --error --title="Error" --text="Record does not exist."
			    			break;
			    		fi
						
						# check if field name entered by user exists in table
			    		for f in $col; do 
			    			if [[ $fname == $f ]]; then 
			    				count=1
								for d in $dt; do
									if [[ $count == $idx ]];then
										datype=$d # dt holds datatype of field
										break;
									fi
									((count++))
								done
								case $datype in
									"integer")
										if ! [[ "$newval" =~ ^[0-9]+$ ]];then
											zenity --error --title="Error" --text="Invalid datatype."
											#break;
											continue;
										fi
							    	;;
									"string")
										if ! [[ "$newval" =~ ^[a-zA-Z]+$ ]];then
											zenity --error --title="Error" --text="Invalid datatype."
											continue;
										fi
									;;
									"float")
										if ! [[ "$newval" =~ ^[0-9]+(\.[0-9]+)?$ ]];then
											zenity --error --title="Error" --text="Invalid datatype."
						    				continue;
						    			fi
						    		;;
							    esac
			    				# if field is PK then newval must be unique
			    				if [[ $PKfield == $f ]]; then
				    				unique=$(awk -F: -v PKidx=$PKidx -v newval=$newval 'NR > 3 {if($PKidx==newval){print -1}}' ~/myDB/$dbname/$tablename)
									if [[ $unique == -1 ]]; then
										zenity --error --title="Error" --text="$fname is a Primary key. MUST be UNIQUE."
										continue;
									fi
								fi
								data=$(awk -F: -v idx=$idx -v ridx=$ridx -v val=$val -v newval=$newval '{ 
									OFS=":"
									if($ridx == val && NR > 3){
									for(i=1;i<=NF;i++){ 
										if(i==idx){
										    $i=newval;
									    	break;
										} 
									} 
									}
									print $0
								}' ~/myDB/$dbname/$tablename > temp && mv temp ~/myDB/$dbname/$tablename)
								zenity --info --title="Success" --text="Records are updated successfully."
								break 2;
							#elif [[ $fname != $f && $f == ${col##* } ]]; then
			    			#	zenity --error --title="Error" --text="Field does not exist." 
			    			fi
			    			((idx++))
			    		done
			    	fi
				fi
				done
			#else
			#	zenity --error --title="Error" --text="Table does not exist."
			#fi
		else
			zenity --error --title="Error" --text="Table name cannot be empty."
		fi
	fi
}

# Main Menu
while true; do
    choice=$(zenity --list \
    	--width=600 \
    	--height=600 \
        --title="DBMS Menu" \
        --column="Table Operations" \
        "Create Table" \
        "List Tables" \
        "Drop Table" \
        "Insert into Table" \
        "Select from Table" \
        "Delete from Table" \
        "Update Table" \
        "Back")
    
    if [[ $? == 1 ]]; then
    	break;
    fi
    
    case $choice in
        "Create Table") create_table ;;
        "List Tables") list_tables ;;
        "Drop Table") drop_table ;;
        "Insert into Table") insert_into_table ;;
        "Select from Table") select_from_table ;;
        "Delete from Table") delete_from_table ;;
        "Update Table") update_table ;;
        "Back") break ;;
        *) break ;;
    esac
done
