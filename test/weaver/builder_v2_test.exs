defmodule Weaver.BuilderV2Test do
  use ExUnit.Case, async: true

  defmodule Image do
    defstruct id: nil
  end

  defmodule ImageProvider do
    def find(ids) do
      Enum.reduce(ids, Map.new, fn id, acc ->
        Map.put(acc, id, %Image{id: id})
      end)
    end
  end

  defmodule Book do
    defstruct id: nil, image_id: nil, image: nil
  end

  defmodule Double do
    defstruct source: [], target: []
  end

  defmodule Duplicate do
    defstruct ids: [], target0: [], target1: []
  end

  defmodule BookWrapper do
    defstruct book_id: nil, book: nil
  end

  defmodule BookWrapperContainer do
    defstruct id: nil, book_wrapper: nil
  end

  defmodule CollectionData do
    defstruct book_ids: [], cover_image_id: nil
  end

  defmodule Collection do
    defstruct name: "", data: %CollectionData{}, books: [], cover_image: nil
  end

  defmodule BookProvider do
    def find(ids) do
      Enum.reduce(ids, Map.new, fn id, acc ->
        Map.put(acc, id, %Book{id: id, image_id: "book_#{id}"})
      end)
    end
  end

  defmodule NonBookWrapperProvider do
    def find(ids) do
      Enum.reduce(ids, Map.new, fn id, acc ->
        Map.put(acc, id, %BookWrapper{book_id: nil})
      end)
    end
  end

  defmodule BookWeaver do
    use Weaver.BuilderV2
    weave_one :image, by: ImageProvider, through: [:image_id]
  end

  defmodule BookWrapperWeaver do
    use Weaver.BuilderV2
    weave_one :book, by: BookProvider, through: [:book_id], with: BookWeaver
  end

  defmodule BookWrapperContainerWeaver do
    use Weaver.BuilderV2
    weave_one :book_wrapper, by: NonBookWrapperProvider, through: [:book_id], with: BookWrapperWeaver
  end

  defmodule CollectionWeaver do
    use Weaver.BuilderV2
    weave_one :cover_image, by: ImageProvider, through: [:data, :cover_image_id]
    weave_many :books, by: BookProvider, through: [:data, :book_ids] do
      weave_one :image, by: ImageProvider, through: [:image_id]
    end
  end

  defmodule CollectionImageWeaver do
    use Weaver.BuilderV2
    weave_one :cover_image, by: ImageProvider, through: [:data, :cover_image_id]
    weave_many :block do
      weave_one :image, by: ImageProvider, through: [:image_id]
    end
  end

  defmodule GenericBookWeaver do
    def weave(books) do
      case books do
        %{__struct__: Book} -> %{books| image: %Image{id: "default_image"}}
        x when is_list(x) -> Enum.map(x, &GenericBookWeaver.weave(&1))
      end
    end
  end

  defmodule CompositeCollectionWeaver do
    use Weaver.BuilderV2
    weave_one :cover_image, by: ImageProvider, through: [:data, :cover_image_id]
    weave_many :books, by: BookProvider, through: [:data, :book_ids], with: BookWeaver
  end

  defmodule GenericCompositeWeaver do
    use Weaver.BuilderV2

    weave_many :books, by: BookProvider, through: [:data, :book_ids], with: GenericBookWeaver

  end

  defmodule DoubleWeaver do
    use Weaver.BuilderV2

    weave_many :target, through: [:source]
  end

  defmodule DuplicateWeaver do
    use Weaver.BuilderV2
    weave_one :target0, through: [:ids]
    weave_many :target1, through: [:target0]
  end

  defmodule DuplicateWeaverReversed do
    use Weaver.BuilderV2
    weave_many :target0, through: [:target1]
    weave_one :target1, through: [:ids]
  end

  test "should export weave/1" do
    [%Book{id: "1", image_id: "book_1"}] |> BookWeaver.weave
  end

  test "should export cards/0" do
    BookWeaver.cards
  end

  describe "weave/1" do
    test "should weave struct" do
      assert %Book{id: "1", image_id: "book_1"} |> BookWeaver.weave
      == %Book{id: "1", image_id: "book_1", image: %Image{id: "book_1"}}
    end

    test "should weave array" do
      assert [%Book{id: "1", image_id: "book_1"}] |> BookWeaver.weave
      == [%Book{id: "1", image_id: "book_1", image: %Image{id: "book_1"}}]
    end

    test "should weave map" do
      assert %{first: %Book{id: "1", image_id: "book_1"}, second: %Book{id: "2", image_id: "book_2"}} |> BookWeaver.weave
      == %{first: %Book{id: "1", image_id: "book_1", image: %Image{id: "book_1"}}, second: %Book{id: "2", image_id: "book_2", image: %Image{id: "book_2"}}}
    end

    test "should weave tuple" do
      assert {%Book{id: "1", image_id: "book_1"}, %Book{id: "2", image_id: "book_2"}} |> BookWeaver.weave
      == {%Book{id: "1", image_id: "book_1", image: %Image{id: "book_1"}}, %Book{id: "2", image_id: "book_2", image: %Image{id: "book_2"}}}
    end

    test "should weave nested object" do
      assert %Collection{name: "test", data: %CollectionData{book_ids: ~w{1 2}, cover_image_id: "cover_image"}} |> CollectionWeaver.weave
      ==
      %Collection{name: "test", data: %CollectionData{book_ids: ~w{1 2}, cover_image_id: "cover_image"},
        books: [
          %Book{id: "1", image_id: "book_1", image: %Image{id: "book_1"}},
          %Book{id: "2", image_id: "book_2", image: %Image{id: "book_2"}}
        ],
        cover_image: %Image{id: "cover_image"}
      }
    end

    test "should weave nested object list" do
      assert [
        %Collection{name: "test1", data: %CollectionData{book_ids: ~w{1}, cover_image_id: "cover_image_1"}},
        %Collection{name: "test2", data: %CollectionData{book_ids: ~w{2}, cover_image_id: "cover_image_2"}}
      ] |> CollectionWeaver.weave
      ==
      [
        %Collection{name: "test1", data: %CollectionData{book_ids: ~w{1}, cover_image_id: "cover_image_1"},
          books: [
            %Book{id: "1", image_id: "book_1", image: %Image{id: "book_1"}},
          ],
          cover_image: %Image{id: "cover_image_1"}
        },
        %Collection{name: "test2", data: %CollectionData{book_ids: ~w{2}, cover_image_id: "cover_image_2"},
          books: [
            %Book{id: "2", image_id: "book_2", image: %Image{id: "book_2"}},
          ],
          cover_image: %Image{id: "cover_image_2"}
        }
      ]
    end

    test "should weave with a generic weaver" do
      assert(%Collection{name: "test", data: %CollectionData{book_ids: ~w{1}}} |> GenericCompositeWeaver.weave
      ==
        %Collection{name: "test", data: %CollectionData{book_ids: ~w{1}}, books: [
          %Book{id: "1", image_id: "book_1", image: %Image{id: "default_image"}}
        ]}
      )
    end

    test "weave_one should work with :with weaver" do
      assert %BookWrapper{book_id: "1"} |> BookWrapperWeaver.weave
      ==
        %BookWrapper{book_id: "1", book: %Book{
          id: "1", image_id: "book_1", image: %Image{id: "book_1"}
        }}
    end

    test "should copy target to source if no provider is provided" do
      assert %Double{source: [1, 2, 3]} |> DoubleWeaver.weave
      ==
        %Double{source: [1, 2, 3], target: [1, 2, 3]}
    end

    test "should obey the declaration order for weavers" do
      duplicate = %Duplicate{ids: [1, 2, 3]}
      assert duplicate |> DuplicateWeaver.weave == %Duplicate{ids: [1, 2, 3], target0: [1, 2, 3], target1: [1, 2, 3]}
      assert duplicate |> DuplicateWeaverReversed.weave == %Duplicate{ids: [1, 2, 3], target0: [], target1: [1, 2, 3]}
    end

    test "should weave a nil object" do
      assert nil |> BookWeaver.weave == nil
    end

    test "should weave a nested nil object" do
      assert %BookWrapperContainer{id: "1"} |> BookWrapperContainerWeaver.weave
      == %Weaver.BuilderV2Test.BookWrapperContainer{book_wrapper: nil, id: "1"}
    end
  end
end
