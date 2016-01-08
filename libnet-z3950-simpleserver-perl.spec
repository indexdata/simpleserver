%define idmetaversion %(. ./IDMETA; echo $VERSION)
Summary: Perl API to the YAZ generic front-end server (Z39.50 server)
Name: libnet-z3950-simpleserver-perl
Version: %{idmetaversion}
Release: 1.indexdata
License: Perl
Group: Applications/Internet
Vendor: Index Data ApS <info@indexdata.com>
Source: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-root
BuildRequires: perl
BuildRequires: libyaz5-devel >= 5.0.0
# On Centos6: BuildRequires: perl-ExtUtils-MakeMaker
Packager: Jakub Skoczen <jakub@indexdata.dk>
URL: http://www.indexdata.com/simpleserver/

Requires: libyaz5 >= 5.0.0

%description
The SimpleServer module is a tool for constructing Z39.50 "Information
Retrieval" servers in Perl. The module is easy to use, but it
does help to have an understanding of the Z39.50 query
structure and the construction of structured retrieval records.

%prep
%setup

%build
perl Makefile.PL PREFIX=$RPM_BUILD_ROOT/usr
make

%install
make pure_install
# Perl's make install seems to create both uncompressed AND compressed
# versions of the manual pages, which confuses /usr/lib/rpm/brp-compress
find $RPM_BUILD_ROOT/usr/share/man -name '*.gz' -exec rm -f '{}' \;

# Install additional documentation
DOCDIR=$RPM_BUILD_ROOT%{_datadir}/doc/perl-simpleserver
mkdir -p $DOCDIR
cp -p README.md Changes $DOCDIR/

%clean
rm -fr ${RPM_BUILD_ROOT}

%check
make test

%files
%defattr(-,root,root)
%{_libdir}/perl5
%doc %{_mandir}/man3/*.3*
%doc %{_datadir}/doc/perl-simpleserver
