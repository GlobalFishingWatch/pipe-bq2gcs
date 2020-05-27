#!/usr/bin/env python

"""
Setup script for pipe-bq2gcs
"""
from pipe_tools.beam.requirements import requirements as DATAFLOW_PINNED_DEPENDENCIES

import codecs

from setuptools import find_packages
from setuptools import setup

package = __import__('pipe_bq2gcs')

DEPENDENCIES = [
    "pipe-tools==3.1.1",
    "jinja2-cli",
    "jinja2==2.11.2",
    "jsonschema==3.2.0"
]

with codecs.open('README.md', encoding='utf-8') as f:
    readme = f.read().strip()

with codecs.open('requirements.txt', encoding='utf-8') as f:
    DEPENDENCY_LINKS=[line for line in f]

setup(
    author=package.__author__,
    author_email=package.__email__,
    dependency_links=DEPENDENCY_LINKS + DATAFLOW_PINNED_DEPENDENCIES,
    description=package.__doc__.strip(),
    include_package_data=True,
    install_requires=DEPENDENCIES,
    license=package.__license__.strip(),
    long_description=readme,
    name='pipe-bq2gcs',
    packages=find_packages(exclude=['test*.*', 'tests']),
    url="https://github.com/GlobalFishingWatch/pipe-bq2gcs",
    version=package.__version__,
    zip_safe=True
)
