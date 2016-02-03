#!/usr/bin/env bash

### t
### a thing for keeping your "i'll just stash this here..." stuff in order
### john slee <john.slee@fairfaxmedia.com.au> 
### Tue  2 Feb 2016 22:53:53 AEDT

ttop="$HOME/t"
trc="$home/.trc"
if [ -f "$trc" ] ; then
	source $HOME/.trc
fi

warn() {
	echo "$(basename $0): WARN: $*" 1>&2
}

die() {
	echo "$(basename $0): FATAL: $*" 1>&2
	exit 1
}

# initial setup. is run automatically, probably no need to manually invoke
setup() {
	test -d "$ttop" \
		|| mkdir -m700 "$ttop" \
		|| die "can't do basic setup, halp: $ttop"
	cd "$ttop" \
		|| die "can't use configured directory: $ttop"
}

newid() {
    ( \
        if which uuidgen > /dev/null ; then
            uuidgen
        else
            # a compromise but still "good enough for government work..."
            ( echo $$ ; tty ; id ; hostname ; date +%s ; w ; pwd )
        fi
    ) | openssl sha | sed -n 's/^\([a-f0-9]\{7\}\).*$/\1/p'
    # use openssl sha because the name of the sha commandline util
    # seems inconsistent. some OS have sha1sum, some have shasum
}

ids() {
	find "$ttop" -type d -maxdepth 1 -mindepth 1 -print | sed "s:$ttop/::"
}

list() {
	printf "%-19s  %-2s  %-7s  %-s\n" "CREATED ON" "GC" "ID" "TITLE"
	ids | while read id ; do
		if [ -f "$id/.title" -a -f "$id/.timestamp" ] ; then
			gc=N
			if [ -f "$id/.gc" ] ; then
				gc=Y
			fi
			title="$(< $id/.title)"
			timestamp="$(< $id/.timestamp)"
			if [ -n "$title" -a -n "$timestamp" ] ; then
				printf "%-19s  %-2s  %-7s  %-s\n" "$timestamp" "$gc" "$id" "$title"
			fi
		fi
	done | sort -n
}

is_ok() {
	id="$1"
	title="$id/.title"
	timestamp="$id/.timestamp"
	( [ \
		-f "$title" \
		-a -f "$timestamp" \
		-a -n "$(< "$title")" \
		-a -n "$(< "$timestamp")" \
	] ) > /dev/null 2>&1
}

get_id() {
    supplied="$1"
    implied="$T_BUCKET_ID"
    if [ -n "$supplied" ] && is_ok "$supplied" ; then
        echo "$supplied"
    else
        if [ -n "$implied" ] && is_ok "$implied" ; then
            echo "$implied"
        else
            false
        fi
    fi
}

gc() {
	ids | while read id ; do
		if ! is_ok "$id" > /dev/null 2>&1 || [ -f "$id/.gc" ] ; then
			echo "garbage-collecting $id"
			/bin/rm -vrf "$id"
		fi
	done
}

enter() {
	id="$1"
	shift
	if is_ok "$id" ; then
		export T_BUCKET_ID="$id"
		cd "$id"
		exec "$SHELL"
	else
		die "invalid bucket ID: $id"
	fi
}

new() {
	title="$*"
	id="$(newid)"
	path="$ttop/$id"
	mkdir -m700 "$path"	|| die "can't create new bucket: $path"
	cd "$path"		    || die "can't access new bucket: $path"
	echo "$title" > .title
	date "+%F %T" > .timestamp
	"$0" enter "$id"
}

home() {
	if [ -n "$T_BUCKET_ID" ] ; then
		home="$ttop/$T_BUCKET_ID"
		if [ -d "$home" ] ; then
			echo "$ttop/$T_BUCKET_ID"
		else
			die "bucket has vanished: $id"
		fi
	else
		die "not in a bucket right now"
	fi
}

# intended for use in scripting
title() {
	id="$(get_id "$1")"
    [ "$?" == "0" ] || die "no valid ID supplied or implied"
    echo -n "$(< "$id/.title")"
}

status() {
	id="$T_BUCKET_ID"
	if [ -n "$id" ] ; then
		if is_ok "$id" > /dev/null 2>&1 ; then
			echo "in bucket $id: $(< "$id/.title")"
		else
			die "\$T_BUCKET_ID is set to an invalid bucket: $id"
		fi
	else
		echo "not in a bucket"
	fi
}

# mark a bucket for disposal next time gc is invoked
finished() {
	id="$(get_id "$1")"
    [ "$?" == "0" ] || die "no valid ID supplied or implied"
    touch "$id/.gc"
}

# mark a bucket for disposal next time gc is invoked
keep() {
	id="$(get_id "$1")"
    [ "$?" == "0" ] || die "no valid ID supplied or implied"
    rm -f "$id/.gc"
}

# open an OSX Finder window
finder() {
	id="$(get_id "$1")"
    [ "$?" == "0" ] || die "no valid ID supplied or implied"
    open -a Finder "$ttop/$id"
}

setup

command="$1"
shift
case "$command" in
keep|get_id|is_ok|new|enter|title|finished|status|finder)
	$command $@
	;;
setup|home|list|gc)
	$command
	;;
help)
    cat <<EOHELP
usage: $(basename $0) command ARGS

Several commands are available. Optional arguments are shown in [BRACKETS]

    COMMAND  ARGUMENTS     DESCRIPTION
    enter    ID            spawn a subshell in the specified bucket
    finder   [ID]          open the specified bucket in OSX Finder
    finished [ID]          mark the bucket for future garbage collection
    gc                     garbage-collect all invalid or marked buckets
    get_id   [ID]          find and validate a bucket ID, printing to stdout
    home     [ID]          print the path to a bucket to stdout
    is_ok    [ID]          check the health of a bucket
    keep     [ID]          rescue the bucket from future garbage collection
    list                   list all current buckets
    new      BUCKET TITLE  create a new bucket and spawn a subshell inside it
    setup                  create the top-level bucket structure (automatic)
    status                 print ID and title the current bucket to stdout
    title    [ID]          print title of current or specified bucket to stdout

Where an optional ID is specified, the currently-entered bucket will be assumed
if no ID is supplied.

EOHELP
    ;;
*)
	die "invalid command: $command"
	exit 1
;;
esac
