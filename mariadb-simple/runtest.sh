#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/unixODBC/mariadb-simple
#   Description: Simple test for the mysql odbc connector, v2 - beaker rewrite
#   Author: Karel Volny <kvolny@redhat.com>
#   Original author: Tom Lane <tgl@redhat-com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2006-2011 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

# note we keep fake $PACKAGE due to fact that beakerlib handles this variable specially
PACKAGE="unixODBC"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport mariadb55/basic"
        PACKAGES="$PACKAGE mysql-connector-odbc ${mariadbPkgPrefix}mariadb-server"
        if rlIsRHEL 5 ; then
            PACKAGES="$PACKAGES unixODBC-libs"
        fi
        for PKG in $PACKAGES ; do
            rlAssertRpm $PKG
        done
        TestDir=$PWD
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlFileBackup /etc/odbc.ini
        rlRun "cp ${TestDir}/odbc.ini /etc/odbc.ini" 0 "Setting up odbc.ini"
        rlFileBackup /etc/odbcinst.ini
        rlRun "cp ${TestDir}/odbcinst.ini /etc/odbcinst.ini" 0 "Setting up odbcinst.ini"
        # the test was originally written for RHEL5 - change library version for other distros
        if ! rlIsRHEL 5 ; then
            MYODBCLIBS=`rpm -ql mysql-connector-odbc | grep -E libmyodbc[[:digit:]]*.so`
            # strip out non-lib64 part on multilib system
            # ... any better ideas when package arch doesn't need to match the platform (uname -i)?
            if echo $MYODBCLIBS | grep lib64 ; then
                MYODBCLIB=`echo $MYODBCLIBS | grep lib64`
            else
                MYODBCLIB=$MYODBCLIBS
            fi
            rlRun "sed -i -e \"s#\\\$ORIGIN/libmyodbc3.so#$MYODBCLIB#\" /etc/odbcinst.ini" 0 "Changing libmyodbc path to $MYODBCLIB"
        fi
        mariadbStart
        rlRun "echo 'SET PASSWORD FOR \`root\`@localhost = PASSWORD(\"\");' | mysql" 0 'Set empty password to root'
#        rlRun "mariadbCreateTestDB"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "/usr/bin/isql MySQL root -v &> test.out <<EOF
select 123 * 456;
quit
EOF" 0 "Run a trivial query using isql"
        # DEBUG
            cat test.out
        # the output should look like:

        # +---------------------------------------+
        # | Connected!                            |
        # |                                       |
        # | sql-statement                         |
        # | help [tablename]                      |
        # | quit                                  |
        # |                                       |
        # +---------------------------------------+
        # SQL> +---------------------+
        # | 123 * 456           |
        # +---------------------+
        # | 56088               |
        # +---------------------+
        # SQLRowCount returns 1
        # 1 rows fetched
        # SQL> 
        rlAssertGrep "56088" "test.out"
        rlAssertGrep "1 row" "test.out"
        # when there's an error, it looks like, for example:

        # [ISQL]ERROR: Could not SQLConnect
        # [01000][unixODBC][Driver Manager]Can't open lib '$ORIGIN/libmyodbc34.so' : $ORIGIN/libmyodbc34.so: cannot open shared object file: není souborem ani adresářem
        rlAssertNotGrep "ERROR" "test.out"
    rlPhaseEnd

    rlPhaseStartCleanup
        mariadbRestore
        rlFileRestore
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
