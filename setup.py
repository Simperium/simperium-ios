import sys
from distutils.core import setup

install_requires = []
if sys.version_info < (2, 6):
    install_requires.append('simplejson')

setup(
    name='Simperium',
    version='0.0.5',
    author='Andy Gayton',
    author_email='andy@simperium.com',
    package_dir = {'': 'python'},
    packages=['simperium', 'simperium.test'],
    scripts=[],
    # url='http://pypi.python.org/pypi/Simperium/',
    # license='LICENSE.txt',
    description='Python client for the Simperium synchronization platform',
    long_description=open('README.md').read(),
    install_requires=install_requires,)
