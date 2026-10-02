// Package main creates the styled drag-to-install DMG using an existing
// cross-platform HFS+ and UDIF implementation.
package main

import (
	"flag"
	"log"
	"path/filepath"

	"github.com/leaanthony/dmg/dmg"
)

func main() {
	app := flag.String("app", "", "exported Project Graph.app directory")
	output := flag.String("output", "", "destination DMG")
	background := flag.String("background", "", "720 by 460 installation background")
	icon := flag.String("icon", "", "volume icon")
	flag.Parse()
	if *app == "" || *output == "" || *background == "" {
		log.Fatal("-app, -output and -background are required")
	}
	err := dmg.Build(dmg.Options{
		VolumeName:             "Project Graph",
		OutputPath:             *output,
		Backend:                dmg.BackendNative,
		Files:                  map[string]string{filepath.Base(*app): *app},
		AddApplicationsSymlink: true,
		Window:                 dmg.WindowConfig{X: 200, Y: 120, Width: 720, Height: 460},
		Icon:                   dmg.IconConfig{Size: 96, TextSize: 13, GridSpace: 100},
		Background:             &dmg.BackgroundConfig{File: *background},
		IconPositions: map[string]dmg.IconPosition{
			filepath.Base(*app): {X: 200, Y: 248},
			"Applications":      {X: 520, Y: 248},
		},
		VolumeIcon: *icon,
	})
	if err != nil {
		log.Fatal(err)
	}
}
