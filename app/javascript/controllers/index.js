// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application";
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading";

import ViewToggleController from "./view_toggle_controller";
application.register("view-toggle", ViewToggleController);

eagerLoadControllersFrom("controllers", application);
