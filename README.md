# Weaver

Weave objects together by their external ids

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `weaver` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:weaver, "~> 0.1.0"}]
    end
    ```

  2. Ensure `weaver` is started before your application:

    ```elixir
    def application do
      [applications: [:weaver]]
    end
    ```

# Why Weaver ?
For an invariable language like Elixir, compose objects together can always be a pain.
Consider export a object with all the images it has, and all the images that its associated objects has, like this:
```
Listing:
  cover: Image
  houses: [House]
House:
  cover: Image
  owner: User
User:
  avatar: Image
```
Getting all the images directly or indirectly associated to the `Listing` object is painful. Not to mention, we have to cram them back to the appropriate position.

The `Weaver` comes to help, to
* Do topological sorting bases on the dependencies between objects, to determine the most efficient way to fetch objects with different type (at compile time, Woo! Yeah! no performance penalty!)
* Walk through the tree to collect corresponding ids
* Batch query objects of the same type
* Cram the fetched objects back to appropriate position

# Usage

Basically the weaver system composes by two parts:
  1. Providers, which accept several ids and return a Map mapping from id to corresponding object(s)
  2. Weavers, which define how to weave objects provided by providers into the target object

Here is a quick example:
  ```elixir

    # Assuming we have a Book module, and every book has a cover image specified by the image_id attribute
    defmodule ImageProvider do
      def find(ids) do
        Enum.reduce(ids, Map.new, fn id, acc ->
          Map.put(acc, id, %Image{id: id})
        end)
      end
    end
    defmodule BookWeaver do
      use Weaver.BuilderV2
      # weave_one target, by: which_provider, though: which_external_id
      weave_one :cover, by: ImageProvider, through: [:image_id]
    end
  ```
`ImageProvider` provides Image by giving image_ids, and the `BookWeaver` defines how `Image` get weaved into the `Book` object. After defined the provider, and weaver, we can:

* Weave a single object:
  ```elixir
    assert %Book{id: "1", image_id: "book_1"} |> BookWeaver.weave
        == %Book{id: "1", image_id: "book_1", image: %Image{id: "book_1"}}
  ```
* Weave a collections of objects:
  ```elixir
    # weave a list of objects
    assert [%Book{id: "1", image_id: "book_1"}] |> BookWeaver.weave
      == [%Book{id: "1", image_id: "book_1", image: %Image{id: "book_1"}}]

    # weave a map of objects
    assert %{first: %Book{id: "1", image_id: "book_1"}, second: %Book{id: "2", image_id: "book_2"}} |> BookWeaver.weave
      == %{first: %Book{id: "1", image_id: "book_1", image: %Image{id: "book_1"}}, second: %Book{id: "2", image_id: "book_2", image: %Image{id: "book_2"}}}

    # weave a tuple of objects
    assert {%Book{id: "1", image_id: "book_1"}, %Book{id: "2", image_id: "book_2"}} |> BookWeaver.weave
    == {%Book{id: "1", image_id: "book_1", image: %Image{id: "book_1"}}, %Book{id: "2", image_id: "book_2", image: %Image{id: "book_2"}}}
  ```

As simple as it should be~

## Define A Provider
Provider is just a behaviour defining a function named `find` with the type `([id] -> %{id => any()})`

A typical Provider defines like this (use [ecto](https://github.com/elixir-ecto/ecto) as database wrapper)
  ```elixir
    defmodule UserProvider do
      import Ecto.Query
      def find(ids) do
        from(o in User)
        |> where([o], o.id in ^ids)
        |> Flatie.Repo.all
        |> Enum.reduce(Map.new, fn user, map->
          Map.put(map, user.id, user)
        end)
      end
    end
  ```

## Define A Weaver
Weaver is just another behaviour defining a function named `weave` with the type `(any() -> any())`.
So without our builder, you can simply define a dump Weaver:
  ```elixir
    defmodule DumpWeaver do
      def weave(any), do: any
    end
  ```
To do the complicate things you can use our builder `Weaver.BuilderV2` (We have shifted to the version 2).
To use it, just include `use Weaver.BuilderV2` in you weaver ( as we have seen in the quick example). After that you can have two very useful directives `weave_one` and `weave_many` at you hand. As their names implied
* `weave_one`: used to handle the one-one mapping
* `weave_many`: used to handle the one-many mapping

The two directives, can be used in three ways
1. The normal way
  `weave_(one|many) target, by: your_provider, though: the_id_path`
2. The compositional way
  `weave_(one|many) target, with: another_weaver`
3. The mix. The weaver will work in the normal way first, then is the compositional way
  `weave_(one|many) target, by: your_provider, though: the_id_path, with: another_weaver`

`target`(atom()) the target field you want to weave into
`your_provider`: the provider that provides the ids referenced objects
`the_id_field`([atom()]): the relative path to find the id
`another_weaver`: just another weaver, use the same weaver will form a hazardous loop, so don't try

To make things easier (avoid defining too many un-reusable Weavers), we introduced a syntax to define `inline weaver`
  ```elixir
    weave_many :books do
      weave_one :image, by: ImageProvider, through: [:image_id]
      weave_many :taxons, by: TaxonProvider, through: [:taxon_ids]
    end
  ```

## Examples
Here's a full example from our project
  ```elixir
    defmodule ListingWeaver do
      use Weaver.BuilderV2
      weave_one :community, by: CommunityProvider, through: [:community_id], with: Flatie.CommunityWeaver
      weave_one :offering, by: OfferingProvider, through: [:offering_id]
      weave_many :listing_properties, by: ListingPropertyProvider, through: [:data, :properties], with: ListingPropertyWeaver
      weave_one :cover_image, by: ImageProvider, through: [:data, :cover_image_id]
      weave_many :images, by: ListingImageProvider, through: [:data, :images] do
        weave_one :image, by: ImageProvider, through: [:id]
        weave_many :taxons, by: TaxonProvider, through: [:taxon_ids]
      end
    end
  ```
