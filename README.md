# t

## Usage

`t` is a utility to help you stash that temporary gunk and hopefully find it again later.

### Initial setup

Install `t` somewhere in your `$PATH`.

    $ sudo cp t /usr/local/bin/t

Configuration is a one-liner, just telling it where to store things:

    $ echo 'ttop=$HOME/t' > $HOME/.trc

### Creating a stash bucket:

    $ t new evil birthday idea

A bucket is created and a new subshell spawned inside the bucket. The variable `$T_BUCKET_ID` is set in the subshell's environment

Once in the new subshell...

    $ pwd
    /Users/jslee/t/6c214a3616b5

### Listing the buckets

    $ t list
    CREATED ON           GC  ID            TITLE
    2016-02-02 22:41:17  Y   1b58bace38cd  testing 123
    2016-02-02 22:57:16  N   6c214a3616b5  evil birthday idea
    2016-02-02 22:44:50  Y   f760116d49cf  test

### Entering an existing bucket

    $ t enter 6c214a3616b5

    $ pwd
	/Users/jslee/t/6c214a3616b5

### Open a bucket in Finder

    $ t finder 6c214a3616b5

Or if you've already entered the bucket...

    $ t finder

### Marking a bucket for later garbage collection

    $ t finished 6c214a3616b5

### Garbage collection

    $ t gc


## Ideas

### Sync across multiple systems

If you're using OS X, are signed into iCloud and have configured iCloud
Drive, you can stash the buckets in there and have them synced across
all of your devices. Probably don't put sensitive stuff in there,
though.

Blah blah Dropbox blah Google Drive blah blah. All possible, I'm sure.

### Shell prompt integration

A sample shell function is included for integration with `bash-git-prompt`.
You can find this in `t.sh`.

### Shell tab-completion

This *probably* wouldn't be too hard to implement.


## Bugs

Yep, there'll be some. PRs welcomed :-)


## Who?

John Slee <john.slee@fairfaxmedia.com.au>


## License

Apache 2.0. See LICENSE file.
