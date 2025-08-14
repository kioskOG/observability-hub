package scooter

import (
	"context"

	"github.com/grafana/pyroscope-rideshare-go/rideshare"
	"github.com/grafana/pyroscope-rideshare-go/utility"
)

func OrderScooter(ctx context.Context, searchRadius int64) {
	rideshare.Log.Printf(ctx, "ordering scooter, with searchRadius=%d", searchRadius)
	utility.FindNearestVehicle(ctx, searchRadius, "scooter")
}
