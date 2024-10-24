#!/bin/dash

########## COMMENTAIRES ##########

# Persello Maxence TP1B et Paillard Paul TP1B

# Toutes les fonctions sont implémentées, nous avons testé les fonctions dans les
# conditions normales d'utilisations mais également dans le cas où le fichier 
# donné en entrée ne serait pas sous versionnage ou que l'entrée ne serait
# pas un fichier régulier, sans permition de lecture, etc.
# Par rapport à ce qu'on m'a indiqué en tp non la fonction amend n'est pas
# capable de retirer le commit d'un fichier pour le faire sur un autre, le amend
# dans notre cas est naif au sens où il revient d'une version en arrière et
# commit la version modifiée.


# Dans ce projet nous avons choisi de répartir par fonction le travail, attention
# aux fonctions dépendantes d'autres où là nous avons travaillé ensemble sur le
# même problème.


########## DEBUT DU PROGRAMME ##########




### HELP ### 


usage_command() {
	echo "Usage:
	./version.sh --help
	./version.sh <command> FILE [OPTION]
	where <command> can be: add amend checkout|co commit|ci diff log reset rm"
}

help_command() {
	usage_command
	echo "

./version.sh add FILE MESSAGE
	Add FILE under versioning with the initial log message MESSAGE

./version.sh commit|ci FILE MESSAGE
	Commit a new version of FILE with the log message MESSAGE

./version.sh amend FILE MESSAGE
	Modify the last registered version of FILE, or (inclusive) its log message

./version.sh checkout|co FILE [NUMBER]
	Restore FILE in the version NUMBER indicated, or in the
	latest version if there is no number passed in argument

./version.sh diff FILE
	Displays the difference between FILE and the last committed version

./version.sh log FILE
	Displays the logs of the versions already committed

./version.sh reset FILE NUMBER
	Restores FILE in the version NUMBER indicated and
	deletes the versions of number strictly superior to NUMBER

./version.sh rm FILE
	Deletes all versions of a file under versioning"
}



### SUB FUNCTIONS ###


version_control() {
	if [ ! -d "$dir/.version" ] || [ ! -f "$dir/.version/$filename.latest" ]; then
		echo "'$filename' is not under version control."
		echo "Enter './version.sh --help' for more information." >&2
		exit 1
	fi
}



### ADD A LOG ###


log_add() {

	# Get command line arguments
	dir=$(dirname "$1")
	filename=$(basename "$1")
	log=$2

	# Verify log not empty
	if [ -z "$log" ] || [ $(echo "$log" | wc -l) -ne 1 ]; then
		echo "Error! '$2' is null or over several lines." >&2
		echo "Enter './version.sh --help' for more information." >&2
		exit 1
	fi

	# Remove first and last spaces
	log=$(echo "$log" | sed 's/^[ \t]*//;s/[ \t]*$//')

	# Check if log exists and create it if necessary
	echo "$(date -R) '$log'" >> "$dir/.version/$filename.log"
}



### ADD ###


add_command() {

	filename=$(basename "$1")
	file=$1

	# Check if the file exists and is a regular file with read permission
	if [ ! -f "$file" ] || [ ! -r "$file" ]; then
		echo "Error! '$file' is not a regular file or read permission is not granted." >&2
		echo "Enter './version.sh --help' for more information." >&2
		exit 1
	fi

	# Check if the version directory exists and create it if necessary
	version_dir="$(dirname "$file")/.version"
	if [ ! -d "$version_dir" ]; then
		mkdir "$version_dir"
	fi

	# Check if the file is already under version control
	if [ -e "$version_dir/$filename.latest" ]; then
		echo "'$filename' is already under version control."
		echo "Enter './version.sh --help' for more information." >&2
		exit 1
	fi

	# Check if the log is valid
	log_add $1 "$2"

	# Create the necessary files for version control
	cp "$file" "$version_dir/$filename.1"
	cp "$file" "$version_dir/$filename.latest"

	# Print a success message
	echo "Added a new file under versioning: '$filename'"
}



### RM ###


rm_command() {

	# Extract the directory and filename from the argument
	dir=$(dirname "$1")
	filename=$(basename "$1")

	# Check if the FILE is under version control
	version_control

	# Ask for confirmation before proceeding with the deletion
	read -p "Are you sure you want to delete '$filename' from versioning ? (yes/no) " answer
	case $answer in
		yes)
			# Delete all the files related to the FILE under version control
			rm "$dir/.version/$filename"*
			echo "'$filename' is not under versioning anymore."

			# Remove the version directory if it is empty
			if [ -z "$(ls -A $dir/.version)" ]; then
				rmdir "$dir/.version"
			fi
			;;
		*)
			echo "Nothing done."
			;;
	esac
}



### COMMIT ###


commit_command() {

	# Get command line arguments
	dir=$(dirname "$1")
	filename=$(basename "$1")
	file=$1

	# Check if the FILE is under version control
	version_control

	# Check if the current file is different from the latest version
	if ! cmp -s "$dir/.version/$filename.latest" "$file"; then

		# Check if the log is valid
		log_add $1 "$2"

		# Find current version number
		version=$(ls "$dir/.version/" | grep "^$filename.[0-9]" | wc -l | bc)
		version=$(($version+1))

		# Create patch file
		diff -u "$dir/.version/$filename.latest" "$file" > "$dir/.version/$filename.$version"

		# Update latest version file
		cp "$file" "$dir/.version/$filename.latest"

		echo "Version $version committed successfully for file $file."
	else
		echo "File $file is identical to the latest version, no commit needed."
	fi
}



### DIFF ###


diff_command() {

	# Get command line arguments
	dir=$(dirname "$1")
	filename=$(basename "$1")
	file=$1

	# Check if the FILE is under version control
	version_control

	# Echo diff between last and current version
	diff -u "$dir/.version/$filename.latest" "$file" | cat
}



### CHECKOUT ###


checkout_command() {

	# Get command line arguments
	dir=$(dirname "$1")
	filename=$(basename "$1")
	file=$1

	# Check if the FILE is under version control
	version_control

	# Find maximum version number
	version=$(($(ls "$dir/.version" | grep "^$filename.*" | wc -l | bc)-1))

	# Determinate version
	if [ $# -eq 2 ]; then
		if [ $2 -lt 1 ]; then
			echo "Version does not exists."
			echo "Enter './version.sh --help' for more information." >&2
			exit 1
		elif [ $2 -lt $version ]; then
			version=$2
		elif [ $2 -eq $version ]; then
			version="latest"
		else
			echo "Version does not exists."
			echo "Enter './version.sh --help' for more information." >&2
			exit 1
		fi
	else
		version="latest"
	fi

	# Restore file in specified version
	if [ "$version" = "1" ] || [ "$version" = "latest" ]; then
		cp -p .version/"$filename"."$version" "$file"
	else
		cp -p .version/"$filename".1 "$file"
		for i in $(seq 2 "$version"); do
		patch -s "$file" .version/"$filename"."$i"
		done
	fi

}



### LOG ###


log_command() {

	# Get command line arguments
	dir=$(dirname "$1")
	filename=$(basename "$1")
	file=$1

	# Check if the FILE is under version control
	version_control

	# Print logs
	nl -s ' : ' -w 2 $dir/.version/$filename.log
}



### RESET ###


reset_command() {

	# Get command line arguments
	dir=$(dirname "$1")
	filename=$(basename "$1")
	version_file="$dir/.version/$filename"

	# Checkout file
	checkout_command $1 $2

	# Update latest version file
	cp "$1" "$version_file.latest"

	# Remove other versions
	version=$(ls "$dir/.version/" | grep "^$filename.[0-9]" | wc -l | bc)
	if [ $2 -lt $version ]; then
		for i in $(seq $(($2+1)) $version); do
			rm "$version_file.$i"
		done
	fi

	# Reset log
	head -n $2 "$version_file.log" > "$version_file.log.tmp"
	mv "$version_file.log.tmp" "$version_file.log"

}



### AMEND ###


amend_command() {

	# Get command line arguments
	dir=$(dirname "$1")
	filename=$(basename "$1")
	version_file="$dir/.version/$filename"

	# Check if the FILE is under version control
	version_control

	# Find maximum version number
	version=$(($(ls "$dir/.version" | grep "^$filename.*" | wc -l | bc)-1))

	# Save current file
	cp "$1" "$version_file.tmp"

	# Reset version to previous one
	reset_command $1 $(($version-2))

	# Commit new version
	mv "$version_file.tmp" "$1"
	commit_command $1 "$2" > /dev/null
	echo "Latest version amended : $version"
}




### MAIN ###



if [ $# -eq 0 ];then
	usage_command
	exit 1
elif [ $# -eq 1 ] && [ $1 = "--help" ]; then
	help_command
	exit 1
fi

case $1 in
	--help)
		if [ $# -eq 1 ]; then
			echo "Error! Command unknown" >&2
			usage_command
			exit 0
		fi
		usage_command
		exit 1
		;;
	add) 
		add_command $2 "$3"
		;;
	rm)
		rm_command $2
		;;
	commit|ci)
		commit_command $2 "$3"
		;;
	diff)
		diff_command $2
		;;
	checkout|co)
		checkout_command $2 $3
		;;
	log)
		log_command $2
		;;
	reset)
		reset_command $2 $3
		;;
	amend)
		amend_command $2 "$3"
		;;
	*) 
		usage_command
		exit 1
		;;
esac

exit 0