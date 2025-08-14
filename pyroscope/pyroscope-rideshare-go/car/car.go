package car

import (
	"context"

	"github.com/grafana/pyroscope-rideshare-go/rideshare"
	"github.com/grafana/pyroscope-rideshare-go/utility"
)

func OrderCar(ctx context.Context, searchRadius int64) {
	rideshare.Log.Printf(ctx, "ordering car, with searchRadius=%d", searchRadius)
	utility.FindNearestVehicle(ctx, searchRadius, "car")
}
