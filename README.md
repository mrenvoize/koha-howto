# Koha How-to

The goal of this project is to provide a quick and simple way to immerse yourself in the Koha development process.

It targets people that wants to
 * join the Koha development team
 * submit their first patch
 * test their first patch

## Getting started

### Open an account on bugzilla

To share a patch with the Koha community, or comment on a bug report, you will need to [Create an account](https://bugs.koha-community.org/bugzilla3/createaccount.cgi).

### Koha development environment

You need a working Koha development environment.

The quickest and easiest way to do so is to create a virtual machine using [KohaDevBox](https://github.com/digibib/kohadevbox).

Do not forget to fill the vars/user.yml file with your bugzilla credentials.

### Set up the How-to

Clone this project:

```
% git clone https://github.com/joubu/koha-howto
```

Then copy the file to your Koha git repository. If you are using a virtual machine created with KohaDevBox:

```
% cp how-to.pl /home/vagrant/kohaclone/
% cp how-to.tt /home/vagrant/kohaclone/koha-tmpl/intranet-tmpl/prog/en/modules/
```

Restart Plack

```
% sudo koha-plack --restart kohadev
```

### Follow the tutorial

Hit [/cgi-bin/koha/how-to.pl](http://localhost:8081/cgi-bin/koha/how-to.pl) and follow the different steps of the tutorial.
The first steps are a quick quizz to make sure you understand the basics of our workflow, the you will be guided to:
 * Create your first patch
 * Make sure you patch follows our main guidelines
 * Share your patch with the Koha community
 * Apply a patch on a local branch to test it
 * Attach a signed-off patch to our bug tracker

## Dependencies

All the dependencies you need should be installed by KohaDevBox.

In case it is not done yet, check that you have bugz

```
% apt install bugz
```
