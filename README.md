# Local CSV Upload via Postgrest

## Making Changes Locally

This guide assumes you are already running a local ref data service as described in the [public GitHub repo](https://github.com/UKHomeOffice/RefData) and you have Python 3 available locally. Make sure python script dependencies are met by running `python3 -m pip install -r requirements.txt`.

Now you are ready to make changes. As an example, let's say you want to perform the following changes to the `unit` table:

1. Add a new unit **Donkeypower**.
2. Change **millilitre (ml)** to **Millilitre (ml)** (capitalise it).

To add a new row, choose a new ID that is unique. Considering current *unit* table CSV looks like this:

```csv
id,unit,validfrom,validto,updatedby
1,Document,2019-01-01 00:01:00+00
2,£ GBP,2019-01-01 00:01:00+00
3,Kilogram (Kg),2019-01-01 00:01:00+00
4,Litre (L),2019-01-01 00:01:00+00
5,Item,2019-01-01 00:01:00+00
6,gram (g),2019-01-01 00:01:00+00
7,millilitre (ml),2019-01-01 00:01:00+00
8,Stick,2019-01-01 00:01:00+00
```

The obvious choice for *Donkey power* will be number 9, therefore you can add the following line:

```csv
9,Donkeypower,2021-01-19 00:01:00+00
```
and considering **millilitre (ml)** has id 7, the next row of changes is:

```csv
7,Millilitre (ml),2019-01-01 00:01:00+00
```

To create our change set, we need a CSV chunk that consists of table columns affected, and our changes:

```csv
id,unit,validfrom,validto,updatedby
7,Millilitre (ml),2019-01-01 00:01:00+00
9,Donkeypower,2021-01-19 00:01:00+00
```

### Updating Data

The only problem with the previous example is that we are **not allowed to update data for legal reasons** no matter even if it's just a typo. Therefore, in the previous example we need to deprecate the previous record #7 (set `validto` to now) and create a new one with fixed data, like so:

```csv
id,unit,validfrom,validto,updatedby
7,millilitre (ml),2019-01-01 00:01:00+00,2021-01-19 00:01:00+00
9,Donkeypower,2021-01-19 00:01:00+00
10,Millilitre (ml),2019-01-01 00:01:00+00
```


