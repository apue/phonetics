build:
	swift build

test:
	swift test

headless-seed-check:
	swift run phoneticsctl --headless seed-check

headless-smoke-test:
	swift run phoneticsctl --headless smoke-test

run:
	swift run phoneticsctl --gui

run-gui:
	swift run phoneticsctl --gui

open:
	open Package.swift
