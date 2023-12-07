#!/usr/bin/env python
# -*- coding: utf-8 -*-

from subprocess import run
from shutil import copyfile

from setuptools.command.build_ext import build_ext
from setuptools import setup, Extension, Distribution

try:
    # Added in Python 3.12
    from setuptools.modified import newer
except ImportError:
    from setuptools._distutils.dep_util import newer

#
# hack to support linking when running
#  python setup.py sdist
#

import os

del os.link

if newer("./src/getdate.y", "./src/getdate.c"):
    run(["bison", "-y", "-o", "./src/getdate.c", "./src/getdate.y"], check=True)


def build(setup_kwargs):
    dist = Distribution(
        {
            **setup_kwargs,
            "ext_modules": [
                Extension(
                    "kadmin",
                    libraries=["krb5", "kadm5clnt", "kdb5"],
                    include_dirs=["/usr/include/", "/usr/include/et/"],
                    sources=[
                        "src/kadmin.c",
                        "src/PyKAdminErrors.c",
                        "src/PyKAdminObject.c",
                        "src/PyKAdminIterator.c",
                        "src/PyKAdminPrincipalObject.c",
                        "src/PyKAdminPolicyObject.c",
                        "src/PyKAdminCommon.c",
                        "src/PyKAdminXDR.c",
                        "src/getdate.c",
                    ],
                ),
                Extension(
                    "kadmin_local",
                    libraries=["krb5", "kadm5srv", "kdb5"],
                    include_dirs=["/usr/include/", "/usr/include/et/"],
                    sources=[
                        "src/kadmin.c",
                        "src/PyKAdminErrors.c",
                        "src/PyKAdminObject.c",
                        "src/PyKAdminIterator.c",
                        "src/PyKAdminPrincipalObject.c",
                        "src/PyKAdminPolicyObject.c",
                        "src/PyKAdminCommon.c",
                        "src/PyKAdminXDR.c",
                        "src/getdate.c",
                    ],
                    define_macros=[("KADMIN_LOCAL", "")],
                ),
            ],
        }
    )

    dist.package_dir = {"": "src"}

    cmd = build_ext(dist)
    cmd.ensure_finalized()
    cmd.run()

    for output in cmd.get_outputs():
        relative_extension = os.path.relpath(output, cmd.build_lib)
        copyfile(output, relative_extension)
        mode = os.stat(relative_extension).st_mode
        mode |= (mode & 0o444) >> 2
        os.chmod(relative_extension, mode)
