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
	uuidgen | shasum | sed -n 's/^\([a-f0-9]\{12\}\).*$/\1/p'
}

ids() {
	find "$ttop" -type d -maxdepth 1 -mindepth 1 -print | sed "s:$ttop/::"
}

list() {
	printf "%-19s  %-2s  %-12s  %-s\n" "CREATED ON" "GC" "ID" "TITLE"
	ids | while read id ; do
		if [ -f "$id/.title" -a -f "$id/.timestamp" ] ; then
			gc=N
			if [ -f "$id/.gc" ] ; then
				gc=Y
			fi
			title="$(< $id/.title)"
			timestamp="$(< $id/.timestamp)"
			if [ -n "$title" -a -n "$timestamp" ] ; then
				printf "%-19s  %-2s  %-12s  %-s\n" "$timestamp" "$gc" "$id" "$title"
			fi
		fi
	done | sort -n
}

is_ok() {
	id="$1"
	title="$id/.title"
	timestamp="$id/.timestamp"
	[ \
		-f "$title" \
		-a -f "$timestamp" \
		-a -n "$(< "$title")" \
		-a -n "$(< "$timestamp")" \
	]
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
	cd "$path"		|| die "can't access new bucket: $path"
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
	id="$T_BUCKET_ID"
	if [ -n "$1" ] ; then
		id="$1"
		shift
	fi
	[ -n "$id" ] || die "specify an ID if not in a bucket"
	if is_ok "$id" ; then
		echo -n "$(< "$id/.title")"
	fi
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
	id="$1"
	shift
	if is_ok "$id" ; then
		touch "$id/.gc"
	fi
}

setup

command="$1"
shift
case "$command" in
new|enter|title|finished|status)
	$command $@
	;;
setup|home|list|gc)
	$command
	;;
*)
	die "invalid command: $command"
	exit 1
;;
esac
