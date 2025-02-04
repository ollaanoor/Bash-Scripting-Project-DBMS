#!/usr/bin/bash

create_DB() {
	dbname=$(zenity --entry --title="Create Database" --text="Enter database name:") 
	if [[ $? == 0 ]]; then
		if [[ -n $dbname ]]; then
			if [[ -e ~/myDB/$dbname ]]; then
				zenity --error --title="Error" --text="Database already exists." 
			else 
			    mkdir ~/myDB/$dbname 2>/dev/null
			    zenity --info --title="Success" --text="Database '$dbname' created successfully." 
			fi
		else
			zenity --error --title="Error" --text="Database name cannot be empty." 
		fi
	fi
}

List_DB() {
	if [[ -n $(ls -A ~/myDB) ]]; then
		data=$(ls ~/myDB)
		zenity --text-info --title="Exisitng Databases" --filename=<(echo "$data")
	else 
	    zenity --error --title="Error" --text="No Databases found."
	fi
}

Connect_DB() {	
	#dbname=$(zenity --entry --title="Connect to Database" --text="Enter database name to connect:")
	options=$(ls ~/myDB | tr '\n' '|' | rev | cut -d'|' -f2- | rev)
	dbname=$(zenity --forms --title="Connect to Database" \
	  	--text="                        Select database to connect to                        " \
	    --add-combo="                                       " \
	  	--combo-values="$options")
	if [[ $? == 0 ]]; then
		if [[ -n $dbname ]]; then
			if [[ -e ~/myDB/$dbname ]]; then
			    #source ~/dbgui2.sh $dbname  # This will run the script in the same shell
			    ./dbgui2.sh $dbname # This will run the script in a new shell
			else 
			    zenity --error --title="Error" --text="Database does not exist."
			fi
		else
			zenity --error --title="Error" --text="Database name cannot be empty."
		fi
	fi
}

DROP_DB() {
	options=$(ls ~/myDB | tr '\n' '|' | rev | cut -d'|' -f2- | rev)
	dbname=$(zenity --forms --title="DROP Database" \
	  	--text="                        Select database to drop                        " \
	    --add-combo="                                    " \
	  	--combo-values="$options")
	if [[ $? == 0 ]]; then
		if [[ -n $dbname && $? == 0 ]]; then
			#if [[ -e ~/myDB/$dbname ]]; then
			    rm -r ~/myDB/$dbname
		    	zenity --info --title="Success" --text="Database '$dbname' deleted successfully." 
			#else 
			#    zenity --error --title="Error" --text="Database does not exist." 
			#fi
		else
			zenity --error --title="Error" --text="Database name cannot be empty." 
		fi	
	fi
}

# Main Menu
while true; do
	# Create a directory to store databases if it does not exist
	if [[ ! -d ~/myDB ]]; then
		mkdir ~/myDB
	fi
	
	# Display the main menu
    choice=$(zenity --list \
    	--width=600 \
    	--height=600 \
        --title="DBMS Menu" \
        --column="Database Operations" \
        "Create Database" \
        "List Databases" \
        "Connect to Database" \
        "Drop Database" \
		"Exit")

	# Check if user pressed Cancel or closed the dialog box
    if [[ $? == 1 ]]; then 
    	break;
    fi
    
    case $choice in
        "Create Database") create_DB ;;
        "List Databases") List_DB ;;
        "Connect to Database") Connect_DB ;;
        "Drop Database") DROP_DB ;;
        "Exit") break ;;
        #*) break ;;
    esac
done
