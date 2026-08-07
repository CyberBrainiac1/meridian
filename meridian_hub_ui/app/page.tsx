import { getHubState } from "@/lib/dal";
import { HubSurface } from "@/components/hub-surface";

export default async function HomePage() {
  return <HubSurface initialState={await getHubState()} />;
}
