import { useBackend, useLocalState } from "../backend";
import { Window } from "../layouts";
import { Button, Section, Box, LabeledList, Divider, Tabs, Stack, Collapsible, Flex } from '../components';
import { classes } from 'common/react';

type BlessingData = {
  user: string,
  psypoints: number,
  upgrades: UpgradeData[],
  categories: string[],
};

type UpgradeData = {
  name: string,
  desc: string,
  iconstate: string,
  category: string,
  cost: number,
  times_bought: number,
  can_buy: number,
}

const categoryIcons = {
  "Buildings": "gopuram",
  "Defences": "user-shield",
  "Xenos": "khanda",
  "Primordial": "skull", // wolf-pack-battalion
};

export const BlessingMenu = (props, context) => {
  const { data } = useBackend<BlessingData>(context);

  const {
    psypoints,
    categories,
  } = data;

  const [
    selectedCategory,
    setSelectedCategory,
  ] = useLocalState(context, 'selectedCategory', categories.length ? categories[0] : null);

  return (
    <Window
      title={"Queen Mothers blessings"}
      width={500}
      height={600}>
      <Window.Content scrollable>
        <Section title={"Psychic points: " + (psypoints ? psypoints : 0) + ". What does your hive need, daughter?"}>
          {(categories.length > 0 && (
            <Section
              lineHeight={1.75}
              textAlign="center">
              <Tabs>
                <Stack
                  wrap="wrap">
                  {categories.map(categoryname => {
                    return (
                      <Stack.Item
                        m={0.5}
                        grow={categoryname.length}
                        key={categoryname}>
                        <Tabs.Tab
                          icon={categoryIcons[categoryname]}
                          selected={categoryname === selectedCategory}
                          onClick={() => setSelectedCategory(categoryname)}>
                          {categoryname}
                        </Tabs.Tab>
                      </Stack.Item>
                    );
                  })}
                </Stack>
              </Tabs>
              <Divider />
            </Section>
          ))}
          <Upgrades />
        </Section>
      </Window.Content>
    </Window>
  );
};

const Upgrades = (props, context) => {
  const { data } = useBackend<BlessingData>(context);

  const {
    upgrades,
    categories,
  } = data;

  const [
    selectedCategory,
    setSelectedCategory,
  ] = useLocalState(context, 'selectedCategory', categories.length ? categories[0] : null);

  return (
    <Section>
      <LabeledList>
        {upgrades.length === 0 ? (
          <Box color="red">No upgrades available!</Box>
        ) : (
          upgrades
            .filter(record => record.category === selectedCategory)
            .map(upgrade => (
              <UpgradeEntry
                upgrade_name={upgrade.name}
                key={upgrade.name}
                upgrade_desc={upgrade.desc}
                upgrade_cost={upgrade.cost}
                upgrade_times_bought={upgrade.times_bought}
                upgrade_can_buy={upgrade.can_buy}
                upgradeicon={upgrade.iconstate} />)
            )
        )}
      </LabeledList>
    </Section>
  );
};


type UpgradeEntryProps = {
  upgrade_name: string,
  upgrade_desc: string,
  upgrade_cost: number,
  upgrade_times_bought: number,
  upgrade_can_buy: number,
  upgradeicon: string,
}

const UpgradeEntry = (props: UpgradeEntryProps, context) => {
  const { act } = useBackend<UpgradeData>(context);

  const {
    upgrade_name,
    upgrade_desc,
    upgrade_cost,
    upgrade_times_bought,
    upgrade_can_buy,
    upgradeicon,
  } = props;

  return (
    <Collapsible
      title={`${upgrade_name} (click for details)`}
      buttons={(
        <Button
          disabled={!upgrade_can_buy}
          tooltip={upgrade_cost + " points"}
          onClick={() => act('buy', { buyname: upgrade_name })}>
          Claim Blessing
        </Button>
      )}>
      <UpgradeView
        name={upgrade_name}
        desc={upgrade_desc}
        timesbought={upgrade_times_bought}
        iconstate={upgradeicon}
        cost={upgrade_cost}
      />
    </Collapsible>
  );
};

type UpgradeViewEntryProps = {
  name: string,
  desc: string,
  timesbought: number,
  iconstate: string,
  cost: number,
}

const UpgradeView = (props: UpgradeViewEntryProps, context) => {
  const {
    name,
    desc,
    timesbought,
    iconstate,
    cost,
  } = props;

  return (
    <Flex align="center">
      <Flex.Item grow={1} basis={0}>
        <Box bold fontSize={1.25}>
          {name}
        </Box>
        <Box
          className={classes(['blessingmenu32x32', iconstate])}
          ml={3}
          mt={2}
          style={{
            'transform': 'scale(2) translate(0px, 10%)',
          }}
        />
        <Box bold mt={3}>
          {"Cost: " + cost}
        </Box>
        <Box bold>
          {timesbought + " Bought"}
        </Box>
      </Flex.Item>
      <Flex.Item grow={1} basis={0}>
        <Box
          italic
          ml={-25}
        >
          {desc}
        </Box>
      </Flex.Item>
    </Flex>
  );
};
