package bike

import (
	"context"

	"github.com/grafana/pyroscope-rideshare-go/rideshare"
	"github.com/grafana/pyroscope-rideshare-go/utility"
)

func OrderBike(ctx context.Context, searchRadius int64) {
	rideshare.Log.Printf(ctx, "ordering bike, with searchRadius=%d", searchRadius)
	utility.FindNearestVehicle(ctx, searchRadius, "bike")
}
