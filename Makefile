# Makefile for Autosana CI Unit Tests

.PHONY: test test-verbose

test:
	bats tests/*.bats

test-verbose:
	bats --verbose-run tests/*.bats
