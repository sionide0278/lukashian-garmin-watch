import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class LukashianWatchView extends WatchUi.WatchFace {

    function initialize() {
        WatchFace.initialize();
    }

    function reload() as Void {
        //This will schedule a temporal event as soon as possible:
        //either now, or 5 minutes after the last one, which might be in the past,
        //in which case it will be executed immediately
        var lastTime = Background.getLastTemporalEventTime();
        if (lastTime == null) {
            Background.registerForTemporalEvent(Time.now());
        } else {
            Background.registerForTemporalEvent(lastTime.add(new Time.Duration(5 * 60)));
        }
    }

    function onUpdate(dc as Dc) as Void {
        if (DEBUG) {
            System.println("Updating...");
        }
        
        var data = Storage.getValue(DATA_KEY);

        if (!(data instanceof Dictionary)) {
            reload();
            return;
        }
        if (!data.hasKey("localEpoch")) {
            reload();
            return;
        }
        
        //Note: localEpoch and offsets are specified in seconds, not milliseconds
        //Note: localEpoch has to correspond with exact start of a day, otherwise time of first day cannot be computed
        var localEpoch = data["localEpoch"] as Number;
        var firstDayNumber = data["firstDayNumber"] as Number;
        var firstYearOfDayNumber = data["firstYearOfDayNumber"] as Number;
        var nextYearStartIndex = data["nextYearStartIndex"] as Number;
        var offsets = data["offsets"] as Array<Number>;

        var currentTime = Time.now().value();

        if (DEBUG) {
            System.println("localEpoch: " + localEpoch);
            System.println("firstDayNumber: " + firstDayNumber);
            System.println("firstYearOfDayNumber: " + firstYearOfDayNumber);
            System.println("nextYearStartIndex: " + nextYearStartIndex);
            System.println("offsets: " + offsets);

            System.println("currentTime: " + currentTime);
        }
        
        var index = -1;
        var endOfPreviousDay = 0;
        var startOfDay = 0;
        var endOfDay = 0;
        
        for (var i = 0; i < offsets.size(); i++) {
            if (currentTime <= localEpoch + offsets[i]) { //Offset itself marks end of day, and is still included in day itself
                index = i;

                if (i == 0) {
                    endOfPreviousDay = localEpoch - 1;
                } else {
                    endOfPreviousDay = localEpoch + offsets[i-1];
                }
                startOfDay = endOfPreviousDay + 1;
                endOfDay = localEpoch + offsets[i];

                break;
            }
        }
        if (index == -1) {
            reload();
            return;
        }
        if (DEBUG) {
            System.println("index: " + index);
            System.println("endOfPreviousDay: " + endOfPreviousDay);
            System.println("startOfDay: " + startOfDay);
            System.println("endOfDay: " + endOfDay);
        }

        var totalSecondsOfDay = endOfDay - endOfPreviousDay;
        var passedSecondsOfDay = currentTime - startOfDay; //Use startOfDay, in order not to count current second itself as having passed, thereby achieving [0000-9999]
        if (DEBUG) {
            System.println("totalSecondsOfDay: " + totalSecondsOfDay);
            System.println("passedSecondsOfDay: " + passedSecondsOfDay);
        }

        var proportionPassed = ((passedSecondsOfDay.toDouble() / totalSecondsOfDay.toDouble()) * 10000.toDouble()).toNumber();
        if (DEBUG) {
            System.println("proportionPassed: " + proportionPassed);
        }

        var day = index < nextYearStartIndex ? (firstDayNumber + index) : (index - nextYearStartIndex + 1);
        var year = index < nextYearStartIndex ? firstYearOfDayNumber : (firstYearOfDayNumber + 1);
        if (DEBUG) {
            System.println("day: " + day);
            System.println("year: " + year);
        }

        var timeString = proportionPassed.format("%04d");
        var dateString = day + " - " + year;

        //Note: the actual color to be displayed depends on the device; devices with 24-bit color, for example, will "round" it to (0, 4, 57)
        dc.setColor(Graphics.COLOR_WHITE, (0 << 24) | (0 << 16) | (4 << 8) | 61);
        dc.clear();

        var timeFont = Graphics.FONT_SYSTEM_NUMBER_HOT;
        var dateFont = Graphics.FONT_SYSTEM_SMALL;
        var timeHeight = Graphics.getFontHeight(timeFont) - Graphics.getFontDescent(timeFont);
        var dateHeight = Graphics.getFontHeight(dateFont) - Graphics.getFontDescent(dateFont);
        
        var marginBetweenTimeAndDate = dateHeight * 0.7;
        var offsetTop = marginBetweenTimeAndDate / 2;

        var center = dc.getWidth() / 2;
        var middle = dc.getHeight() / 2;

        //Y-Coordinate of text is at the top of the text
        dc.drawText(center, offsetTop + middle - timeHeight, timeFont, timeString, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(center, offsetTop + middle + marginBetweenTimeAndDate, dateFont, dateString, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
