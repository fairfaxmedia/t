#!/usr/bin/env bash

### t
### a thing for keeping your "i'll just stash this here..." stuff in order
### john slee <john.slee@fairfaxmedia.com.au> 
### Tue  2 Feb 2016 22:53:53 AEDT

set -e

ttop="$HOME/t"
trc="$HOME/.trc"
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
  local du=no
  if [ "$#" = "1" ] && [ "$1" = "du" ] ; then
    du=yes
  fi
  if [ "$du" = "yes" ] ; then
    printf "%-19s  %-2s  %-7s  %-5s %-s\n" "CREATED ON" "GC" "ID" "SIZE" "TITLE"
  else
    printf "%-19s  %-2s  %-7s  %-s\n" "CREATED ON" "GC" "ID" "TITLE"
  fi
	ids | while read id ; do
		if [ -f "$id/.title" -a -f "$id/.timestamp" ] ; then
			local gc=N
			if [ -f "$id/.gc" ] ; then
				local gc=Y
			fi
			local title="$(< $id/.title)"
			local timestamp="$(< $id/.timestamp)"
			if [ -n "$title" -a -n "$timestamp" ] ; then
        if [ "$du" = "yes" ] ; then
          local du="$(du -sh "$id" | awk '{ print $1 }')"
          printf "%-19s  %-2s  %-7s  %-5s  %-s\n" "$timestamp" "$gc" "$id" "$du" "$title"
        else
          printf "%-19s  %-2s  %-7s  %-s\n" "$timestamp" "$gc" "$id" "$title"
        fi
			fi
		fi
	done | sort -n
}

is_ok() {
	local id="$1"
	local title="$id/.title"
	local timestamp="$id/.timestamp"
	( [ \
		-f "$title" \
		-a -f "$timestamp" \
		-a -n "$(< "$title")" \
		-a -n "$(< "$timestamp")" \
	] ) > /dev/null 2>&1
}

get_id() {
  local supplied="$1"
  local implied="$T_BUCKET_ID"
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

shell_can_histfile() {
  echo "$SHELL" | egrep -q '/((ba)?sh|(pd)?ksh[0-9]*)$'
}

enter() {
	local id="$1"
	shift
	if is_ok "$id" ; then
		export T_BUCKET_ID="$id"
    export T_HOME="$ttop/$id"
    # should work for at least ksh and bash
    # untested with true Bourne sh but *should* work?
    if shell_can_histfile ; then
      # add the shell basename to the history filename because shells
      # don't all write history in compatible ways and users might
      # change shells someday... preserving history per $SHELL
      # prevents them stepping on each others' toes (eg. ksh will
      # destroy bash history files)
      export HISTFILE="$T_HOME/.shell_history_$(basename "$SHELL")"
    else
      warn "unrecognised shell 'SHELL=$SHELL'; not attempting to set \$HISTFILE"
    fi
		cd "$id"
		exec "$SHELL"
	else
		die "invalid bucket ID: $id"
	fi
}

new() {
	local title="$*"
	local id="$(newid)"
	local path="$ttop/$id"
	mkdir -m700 "$path"	|| die "can't create new bucket: $path"
	cd "$path"		    || die "can't access new bucket: $path"
	echo "$title" > .title
	date "+%F %T" > .timestamp
	"$0" enter "$id"
}

home() {
	local id="$(get_id "$1")"
  [ -n "$id" ] || die "no valid ID supplied or implied"
	if [ -n "$id" ] ; then
		local home="$ttop/$id"
		if [ -d "$home" ] ; then
			echo "$ttop/$id"
		else
			die "bucket has vanished: $id"
		fi
	else
		die "not in a bucket right now"
	fi
}

# intended for use in scripting (eg. shell prompt hacks)
title() {
	local id="$(get_id "$1")"
  [ -n "$id" ] || die "no valid ID supplied or implied"
  echo -n "$(< "$id/.title")"
}

status() {
	local id="$T_BUCKET_ID"
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
	local id="$(get_id "$1")"
  [ -n "$id" ] || die "no valid ID supplied or implied"
  touch "$id/.gc"
}

# mark a bucket for disposal next time gc is invoked
keep() {
	local id="$(get_id "$1")"
  [ -n "$id" ] || die "no valid ID supplied or implied"
  rm -f "$id/.gc"
}

# open an OSX Finder window
finder() {
  if [ "$(uname)" = "Darwin" ] ; then
    id="$(get_id "$1")"
    [ -n "$id" ] || die "no valid ID supplied or implied"
    open -a Finder "$ttop/$id"
  else
    die "This command requires Apple OS X."
  fi
}

setup

command="$1"
shift
case "$command" in
home|keep|get_id|is_ok|new|enter|title|finished|status|finder)
	$command $@
	;;
setup|gc)
	$command
	;;
list)
  $command "$@"
  ;;
du)
  list du
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
    list     [du]          list all current buckets (optionally with size)
    du                     same as '$(basename $0) list du'
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
